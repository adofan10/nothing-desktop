import QtQuick

// Time-synced lyrics for whatever MPRIS is currently playing.
//
// Source is LRCLIB (lrclib.net) -- open, no key, no account, and it serves LRC
// timestamps rather than plain text, which is what makes the lines move.
// /api/get wants an exact album+duration match and 404s often, so a miss falls
// through to /api/search and picks the closest-length result that actually has
// synced lyrics.
//
// Only fetches while `active` is true (the media sheet is open), and every answer
// is cached for the session, so reopening the sheet on the same track is instant
// and nothing is requested for music you never look at.
Item {
    id: src
    visible: false

    property bool   active: false
    property string track: ""
    property string artist: ""
    property string album: ""
    property real   durationSec: 0

    // "idle" | "loading" | "synced" | "plain" | "instrumental" | "none"
    property string status: "idle"
    // [{ t: seconds, text: "..." }], sorted; t is 0 for unsynced lyrics
    property var lines: []
    readonly property bool synced: status === "synced"
    readonly property bool hasLines: lines.length > 0

    readonly property string key: src.artist + " " + src.track

    // Session cache, bounded. A long listening session would otherwise accumulate
    // one full lyric sheet per track for as long as plasmashell runs.
    property var cache: ({})
    property var cacheOrder: []
    readonly property int cacheLimit: 24

    function _remember(k, result) {
        if (src.cache[k] === undefined) {
            var order = src.cacheOrder
            order.push(k)
            while (order.length > src.cacheLimit) {
                var drop = order.shift()
                delete src.cache[drop]
            }
            src.cacheOrder = order
        }
        src.cache[k] = result
    }

    property var _xhr: null
    readonly property string userAgent: "nothing-kde-rice island (github.com/buddi0812/nothing-kde-rice)"

    // ------------------------------------------------------------------ parsing
    // LRC lines look like "[01:23.45] text", and one line may carry several
    // stamps when a phrase repeats. Metadata tags ([ar:], [by:]) leave no text
    // behind and drop out on their own.
    function parseLrc(text) {
        var out = []
        var rows = String(text).split(/\r?\n/)
        var stampRe = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            var stamps = []
            var m
            stampRe.lastIndex = 0
            while ((m = stampRe.exec(row)) !== null) {
                var frac = m[3] ? parseFloat("0." + m[3]) : 0
                stamps.push(parseInt(m[1], 10) * 60 + parseInt(m[2], 10) + frac)
            }
            if (stamps.length === 0) continue
            var body = row.replace(stampRe, "").trim()
            for (var j = 0; j < stamps.length; ++j) out.push({ t: stamps[j], text: body })
        }
        out.sort(function (a, b) { return a.t - b.t })
        return out
    }

    function parsePlain(text) {
        var out = []
        var rows = String(text).split(/\r?\n/)
        for (var i = 0; i < rows.length; ++i) out.push({ t: 0, text: rows[i].trim() })
        return out
    }

    // Last line whose timestamp has passed. Walks from the previous answer rather
    // than rescanning, so it stays cheap at 10 Hz.
    property int _hint: 0
    function indexFor(sec) {
        var n = src.lines.length
        if (n === 0 || !src.synced) return -1
        var i = Math.max(0, Math.min(n - 1, src._hint))
        while (i > 0 && src.lines[i].t > sec) i--
        while (i + 1 < n && src.lines[i + 1].t <= sec) i++
        if (src.lines[i].t > sec) return -1     // still in the intro
        src._hint = i
        return i
    }

    // ------------------------------------------------------------------ fetching
    function _apply(result) {
        src.lines = result.lines
        src.status = result.status
        src._hint = 0
    }

    function _abort() {
        if (src._xhr) {
            src._xhr.onreadystatechange = function () {}
            src._xhr.abort()
            src._xhr = null
        }
    }

    function _request(url, handler) {
        var xhr = new XMLHttpRequest()
        src._xhr = xhr
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (src._xhr !== xhr) return          // superseded by a newer track
            src._xhr = null
            handler(xhr)
        }
        xhr.open("GET", url)
        // LRCLIB asks clients to identify themselves; QML may refuse the header,
        // which is harmless -- the request still goes through.
        try { xhr.setRequestHeader("User-Agent", src.userAgent) } catch (e) {}
        xhr.send()
    }

    // Slowed and sped-up edits are the same words at a different tempo, so stamps
    // taken from the original run early or late by exactly the length ratio. This
    // desktop's library is full of them. Rescale when the match is plainly the
    // same song at another speed; leave it alone when the gap is small (a
    // different master) or wild (a different cut entirely).
    function _timeScale(matchedSec) {
        if (!(matchedSec > 0) || !(src.durationSec > 0)) return 1
        var r = src.durationSec / matchedSec
        if (r > 0.97 && r < 1.03) return 1
        if (r < 0.6 || r > 1.7) return 1
        return r
    }

    function _fromRecord(rec) {
        if (!rec) return null
        if (rec.instrumental === true) return { status: "instrumental", lines: [] }
        if (rec.syncedLyrics) {
            var parsed = src.parseLrc(rec.syncedLyrics)
            if (parsed.length > 0) {
                var scale = src._timeScale(parseFloat(rec.duration || 0))
                if (scale !== 1) {
                    for (var i = 0; i < parsed.length; ++i) parsed[i].t *= scale
                }
                return { status: "synced", lines: parsed }
            }
        }
        if (rec.plainLyrics) return { status: "plain", lines: src.parsePlain(rec.plainLyrics) }
        return null
    }

    function fetch() {
        src._abort()
        if (!src.track) { src.status = "idle"; src.lines = []; return }

        var k = src.key
        if (src.cache[k] !== undefined) { src._apply(src.cache[k]); return }

        src.status = "loading"
        src.lines = []
        src._hint = 0

        var q = "track_name=" + encodeURIComponent(src.track)
              + "&artist_name=" + encodeURIComponent(src.artist)
        var getUrl = "https://lrclib.net/api/get?" + q
              + "&album_name=" + encodeURIComponent(src.album)
              + "&duration=" + Math.round(src.durationSec)

        src._request(getUrl, function (xhr) {
            var rec = null
            if (xhr.status === 200) {
                try { rec = JSON.parse(xhr.responseText) } catch (e) { rec = null }
            }
            var res = src._fromRecord(rec)
            if (res) { src._remember(k, res); src._apply(res); return }

            // Exact match missed -- most tracks land here, because the album name
            // MPRIS reports rarely matches LRCLIB's to the character.
            src._request("https://lrclib.net/api/search?" + q, function (xhr2) {
                var best = null
                if (xhr2.status === 200) {
                    try {
                        var hits = JSON.parse(xhr2.responseText)
                        var bestScore = -1
                        for (var i = 0; i < hits.length; ++i) {
                            var h = hits[i]
                            // prefer synced, then the closest running time
                            var score = h.syncedLyrics ? 1000 : 0
                            var d = Math.abs(parseFloat(h.duration || 0) - src.durationSec)
                            score -= Math.min(999, d)
                            if (score > bestScore) { bestScore = score; best = h }
                        }
                    } catch (e2) { best = null }
                }
                var res2 = src._fromRecord(best) || { status: "none", lines: [] }
                src._remember(k, res2)
                src._apply(res2)
            })
        })
    }

    // Track metadata arrives in pieces (title first, then artist, then art), so
    // settle before asking, or every song costs three round trips.
    Timer {
        id: settle
        interval: 400
        onTriggered: src.fetch()
    }

    onKeyChanged: {
        src._abort()
        if (src.active) { src.status = "loading"; settle.restart() }
    }
    onActiveChanged: {
        if (src.active) settle.restart()
        else { src._abort(); settle.stop() }
    }
    Component.onDestruction: src._abort()
}
