import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ------------------------------------------------------------ palette
    // Nothing design tokens -- exact values, pure neutral greys (no blue tint).
    readonly property color islandBg: "#000000"   // --black (OLED)
    readonly property color cardBg:   "#111111"   // --surface
    readonly property color cardBg2:  "#1a1a1a"   // --surface-raised
    readonly property color cBorder:  "#333333"   // --border-visible
    readonly property color textHi:   "#ffffff"   // --text-display
    readonly property color textPri:  "#e8e8e8"   // --text-primary
    readonly property color textLo:   "#999999"   // --text-secondary
    readonly property color textDis:  "#666666"   // --text-disabled
    readonly property color nRed:     "#d71921"   // --accent (interrupt only)
    readonly property color nGreen:   "#4a9e5c"   // --success
    readonly property color nAmber:   "#d4a843"   // --warning
    readonly property string fontUI:   "NType 82"
    readonly property string fontMono: "NType 82 Mono"   // ALL CAPS labels

    // ------------------------------------------------------------ clock
    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    readonly property string timeText: Qt.formatDateTime(root.now, "HH:mm")
    readonly property string secText:  Qt.formatDateTime(root.now, "ss")
    readonly property string dateText: Qt.formatDateTime(root.now, "dddd, d MMMM").toUpperCase()

    // ------------------------------------------------------------ stats
    property int  cpuPct: 0
    property int  memPct: 0
    property int  tempC:  0
    property int  volPct: 0
    property bool muted:  false
    property string netName: ""
    property string netType: ""
    property string btName:  ""
    property int  brightPct: 0

    readonly property string statsScript:
        Qt.resolvedUrl("../scripts/stats.sh").toString().replace("file://", "")

    P5Support.DataSource {
        id: statsSource
        engine: "executable"
        connectedSources: [ root.statsScript ]
        interval: 2000
        onNewData: function (source, data) {
            var out = (data["stdout"] || "").trim()
            if (!out) return
            var parts = out.split(String.fromCharCode(31))
            for (var i = 0; i < parts.length; ++i) {
                var eq = parts[i].indexOf("=")
                if (eq < 1) continue
                var k = parts[i].substring(0, eq)
                var v = parts[i].substring(eq + 1)
                switch (k) {
                case "cpu":   root.cpuPct  = parseInt(v) || 0; break
                case "mem":   root.memPct  = parseInt(v) || 0; break
                case "temp":  root.tempC   = parseInt(v) || 0; break
                case "vol":   root.volPct  = parseInt(v) || 0; break
                case "mute":  root.muted   = (v === "1");      break
                case "bright": root.brightPct = parseInt(v) || 0; break
                case "net":   root.netName = v;                break
                case "ntype": root.netType = v;                break
                case "bt":    root.btName  = v;                break
                }
            }
        }
    }

    // ------------------------------------------------------------ power
    P5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter", "PowerDevil"]
    }
    readonly property int batteryPct: (pmSource.data["Battery"] || {})["Percent"] || 0
    readonly property bool hasBattery: ((pmSource.data["Battery"] || {})["Has Battery"]) === true
    readonly property bool onAC: ((pmSource.data["AC Adapter"] || {})["Plugged in"]) === true

    // ------------------------------------------------------------ shell runner
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) { runner.disconnectSource(source) }
    }
    function exec(cmd) { runner.connectSource(cmd) }

    // ------------------------------------------------------------ media
    Mpris.Mpris2Model { id: mprisModel }
    readonly property var  player:    mprisModel.currentPlayer
    readonly property string track:   player ? (player.track  || "") : ""
    readonly property string artist:  player ? (player.artist || "") : ""
    readonly property string albumArt: player ? (player.artUrl || "") : ""
    readonly property bool isPlaying: player ? (player.playbackStatus === Mpris.PlaybackStatus.Playing) : false
    readonly property bool hasMedia:  player !== null && player !== undefined
    readonly property real mediaLength: player ? (player.length || 0) : 0
    readonly property bool canSeek: player ? (player.canSeek === true) : false
    property real mediaPosition: 0

    // MPRIS players only broadcast Seeked() on a jump, so `position` goes stale on its
    // own and the seek bar sat frozen. Ask for it once a second while playing, and take
    // the answer from positionChanged -- updatePosition() resolves over D-Bus, so the
    // value is not there yet when the call returns.
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.hasMedia && root.isPlaying
        onTriggered: if (root.player) root.player.updatePosition()
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            root.mediaPosition = root.player ? (root.player.position || 0) : 0
        }
        function onTrackChanged() {
            root.mediaPosition = 0
            if (root.player) root.player.updatePosition()
        }
        function onPlaybackStatusChanged() {
            if (root.player) root.player.updatePosition()
        }
    }

    onPlayerChanged: {
        root.mediaPosition = 0
        if (root.player) root.player.updatePosition()
    }

    function seekTo(us) {
        if (!root.player || !root.canSeek) {
            return
        }
        var target = Math.max(0, Math.min(root.mediaLength, Math.round(us)))
        root.player.position = target
        root.mediaPosition = target
    }

    function fmtTime(us) {
        if (!us || us <= 0) return "0:00"
        var s = Math.floor(us / 1000000)
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ------------------------------------------------------------ actions
    function setVolume(pct) {
        var v = Math.max(0, Math.min(100, Math.round(pct)))
        root.volPct = v
        root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v + "%")
    }
    function lockScreen() { root.exec("qdbus6 org.kde.screensaver /ScreenSaver Lock") }

    // caffeine (sleep inhibition)
    property bool caffeine: false
    property int  caffeineCookie: 0
    function toggleCaffeine() {
        var svc = pmSource.serviceForSource("PowerDevil")
        if (!root.caffeine) {
            var op = svc.operationDescription("beginSuppressingSleep")
            op["reason"] = "Nothing island: caffeine mode"
            var job = svc.startOperationCall(op)
            job.finished.connect(function (j) {
                root.caffeineCookie = j.result || 0
                root.caffeine = true
            })
        } else {
            var op2 = svc.operationDescription("stopSuppressingSleep")
            op2["cookie"] = root.caffeineCookie
            svc.startOperationCall(op2)
            root.caffeine = false
            root.caffeineCookie = 0
        }
    }

    // do-not-disturb
    NotificationManager.Settings { id: notificationSettings }
    readonly property bool dnd: {
        var u = notificationSettings.notificationsInhibitedUntil
        return u !== undefined && u !== null && !isNaN(u.getTime()) && u.getTime() > Date.now()
    }
    function toggleDnd() {
        if (root.dnd) {
            notificationSettings.notificationsInhibitedUntil = new Date(0)
        } else {
            var d = new Date()
            d.setFullYear(d.getFullYear() + 10)
            notificationSettings.notificationsInhibitedUntil = d
        }
        notificationSettings.save()
    }

    // stopwatch behind the "recording" tile
    property bool swRunning: false
    property int  swSeconds: 0
    Timer {
        interval: 1000; running: root.swRunning; repeat: true
        onTriggered: root.swSeconds++
    }
    readonly property string swText: {
        var m = Math.floor(root.swSeconds / 60)
        var s = root.swSeconds % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // ------------------------------------------------------------ representations
    // The popup is our own frameless PlasmaCore.Dialog (below), NOT fullRepresentation --
    // Plasma would wrap that in its dialog frame and you'd see the panel's rounded corners
    // inside a square box.
    //
    // BUT a panel applet still needs fullRepresentation to EXIST: with only a compact
    // representation declared, Plasma discards it and falls back to a 42x42 placeholder
    // icon. So declare a stub. We never set `expanded`, so it never opens.
    compactRepresentation: CompactPill { island: root }
    fullRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }

    property Item anchorItem: null
    property bool panelOpen: false

    function togglePanel(anchor) {
        if (anchor) root.anchorItem = anchor
        root.panelOpen = !root.panelOpen
    }

    PlasmaCore.Dialog {
        id: islandDialog
        visible: root.panelOpen
        visualParent: root.anchorItem
        location: PlasmaCore.Types.TopEdge
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: true
        flags: Qt.Dialog | Qt.FramelessWindowHint

        onVisibleChanged: if (!visible) root.panelOpen = false

        mainItem: ExpandedPanel {
            island: root
            width:  implicitWidth
            height: implicitHeight
        }
    }

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: root.timeText
    toolTipSubText: root.dateText
}
