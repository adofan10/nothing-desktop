import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

// Now playing, at full island height.
//
// The stage is the point of it: the cover is anchored right and bleeds off the
// pill's edge, a horizontal gradient takes it from solid black on the left to
// untouched art on the right, and the time-synced lyrics scroll up the black
// half. Below that, the ordinary business -- title, scrub, transport, volume.
Item {
    id: sheet
    property var island

    readonly property color cBg:    island ? island.islandBg : "#000000"
    readonly property color cCard:  island ? island.cardBg   : "#111111"
    readonly property color cCard2: island ? island.cardBg2  : "#1a1a1a"
    readonly property color cBor:   island ? island.cBorder  : "#333333"
    readonly property color cHi:    island ? island.textHi   : "#ffffff"
    readonly property color cLo:    island ? island.textLo   : "#999999"
    readonly property color cDis:   island ? island.textDis  : "#666666"
    readonly property string fUI:   island ? island.fontUI   : "sans"
    readonly property string fMono: island ? island.fontMono : "monospace"

    readonly property var player: island ? island.player : null
    readonly property bool hasMedia: island ? island.hasMedia : false
    readonly property bool playing: island ? island.isPlaying : false

    readonly property var lyrics: island ? island.lyrics : null
    readonly property bool showLyrics: lyrics ? lyrics.hasLines : false
    readonly property string lyricStatus: {
        if (!sheet.lyrics || !sheet.hasMedia) return ""
        switch (sheet.lyrics.status) {
        case "loading":      return "SEARCHING LYRICS…"
        case "instrumental": return "INSTRUMENTAL"
        case "none":         return "NO LYRICS FOUND"
        default:             return ""
        }
    }

    // Which line is playing right now. Driven from the change signal rather than
    // bound, because resolving it walks a cursor and a binding must stay pure.
    property int activeLine: -1
    function refreshActive() {
        sheet.activeLine = (sheet.lyrics && sheet.lyrics.synced && sheet.island)
            ? sheet.lyrics.indexFor(sheet.island.positionSec)
            : -1
    }
    Connections {
        target: sheet.island
        function onPositionSecChanged() { sheet.refreshActive() }
    }
    Connections {
        target: sheet.lyrics
        function onLinesChanged() { sheet.refreshActive() }
    }
    Component.onCompleted: sheet.refreshActive()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16.9
        spacing: 13

        // ---------------------------------------------------------- header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 11.7

            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38
                radius: 19; color: sheet.cCard
                Kirigami.Icon {
                    anchors.centerIn: parent; width: 16.9; height: 16.9
                    source: "go-previous"; isMask: true; color: sheet.cHi
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.closeSheet()
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                Text {
                    text: "NOW PLAYING"
                    color: sheet.cHi
                    font.family: sheet.fMono; font.pixelSize: 15; font.letterSpacing: 1.2
                }
                Text {
                    text: sheet.playing ? "PLAYING" : sheet.hasMedia ? "PAUSED" : "NOTHING PLAYING"
                    color: sheet.cLo
                    font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.6
                }
            }

            // player picker -- only earns its space when there is a choice
            Rectangle {
                visible: island && island.playerCount > 1
                Layout.preferredHeight: 30
                Layout.preferredWidth: playerLabel.implicitWidth + 31.2
                radius: 15
                color: sheet.cCard
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6.5
                    Text {
                        id: playerLabel
                        text: (island && island.playerName ? island.playerName : "PLAYER").toUpperCase()
                        color: sheet.cLo
                        font.family: sheet.fMono; font.pixelSize: 9; font.letterSpacing: 0.6
                        elide: Text.ElideRight
                        Layout.maximumWidth: 104
                    }
                    Text {
                        text: "⌄"
                        color: sheet.cLo
                        font.family: sheet.fUI; font.pixelSize: 12
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.cyclePlayer()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: sheet.cBor }

        // ---------------------------------------------------------- stage
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            // negative margin so the cover runs off the right edge of the pill
            // instead of stopping at the content inset
            Layout.rightMargin: -16.9
            clip: true

// ---- cover, anchored right
            Item {
                id: art
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // with nothing to read, the art is allowed to take the room back
                width: Math.round(parent.width * (sheet.showLyrics ? 0.58 : 0.84))
                clip: true
                Behavior on width {
                    NumberAnimation { duration: 320; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0.0, 1.0, 1.0, 1.0] }
                }

                Image {
                    anchors.fill: parent
                    source: island ? island.albumArt : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    asynchronous: true
                    cache: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(island && island.albumArt)
                    text: "♪"
                    color: sheet.cDis
                    font.family: sheet.fUI; font.pixelSize: 52
                }

                // The fade. Solid black where the lyrics sit, untouched art on the
                // right. Painting a scrim rather than fading the image itself is
                // the same result on a black pill, and costs no shader.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#ff000000" }
                        GradientStop { position: 0.30; color: "#e0000000" }
                        GradientStop { position: 0.62; color: "#66000000" }
                        GradientStop { position: 1.00; color: "#00000000" }
                    }
                }
            }

            // ---- lyrics, over the black half
            ListView {
                id: lyricList
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * 0.66)
                clip: true
                visible: sheet.showLyrics
                boundsBehavior: Flickable.StopAtBounds
                // synced lyrics drive themselves; a plain sheet is yours to scroll
                interactive: sheet.lyrics && !sheet.lyrics.synced

                model: sheet.showLyrics ? sheet.lyrics.lines : []
                currentIndex: sheet.activeLine

                // Pin the playing line a third of the way down and let the list
                // slide underneath it -- that is the whole "moving" effect.
                highlightRangeMode: (sheet.lyrics && sheet.lyrics.synced)
                                    ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: Math.round(height * 0.34)
                preferredHighlightEnd: Math.round(height * 0.34)
                highlightMoveDuration: 420
                highlightMoveVelocity: -1

                delegate: Item {
                    id: lyricRow
                    required property int index
                    required property var modelData

                    width: lyricList.width
                    // Fixed row height, and emphasis carried by colour and scale
                    // rather than font size: a size change would reflow the list
                    // under the cursor every single line.
                    height: label.implicitHeight + 15

                    readonly property bool current: lyricRow.index === sheet.activeLine
                    readonly property bool past: sheet.activeLine >= 0 && lyricRow.index < sheet.activeLine

                    // the playing line gets a mark, positioned so it costs no layout
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 0
                        width: 3
                        height: lyricRow.current ? 17 : 0
                        radius: 1.5
                        color: sheet.cHi
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] } }
                    }

                    Text {
                        id: label
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: (lyricRow.modelData && lyricRow.modelData.text) ? lyricRow.modelData.text : "·"
                        color: lyricRow.current ? sheet.cHi : lyricRow.past ? sheet.cDis : sheet.cLo
                        opacity: lyricRow.current ? 1.0 : 0.75
                        font.family: sheet.fUI
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                        transformOrigin: Item.Left
                        scale: lyricRow.current ? 1.06 : 1.0

                        Behavior on color   { ColorAnimation  { duration: 240 } }
                        Behavior on opacity { NumberAnimation { duration: 240 } }
                        Behavior on scale {
                            NumberAnimation { duration: 240; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                        }
                    }

                    TapHandler {
                        enabled: sheet.lyrics && sheet.lyrics.synced && island && island.canSeek
                        onTapped: island.seekTo(lyricRow.modelData.t * 1000000)
                    }
                }
            }

            // ---- the lyric column fades out top and bottom, so lines arrive and
            //      leave instead of being clipped mid-letter
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: lyricList.width
                height: 44
                visible: sheet.showLyrics
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ff000000" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: lyricList.width
                height: 44
                visible: sheet.showLyrics
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#ff000000" }
                }
            }

            // ---- what the left half says when there is nothing to sing along to
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: lyricList.width - 20
                visible: !sheet.showLyrics && sheet.lyricStatus !== ""
                text: sheet.lyricStatus
                color: sheet.cDis
                font.family: sheet.fMono; font.pixelSize: 11; font.letterSpacing: 1.0
                wrapMode: Text.Wrap
            }
        }

        // ---------------------------------------------------------- titles
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3.9

            Text {
                Layout.fillWidth: true
                text: (island && island.track) ? island.track : "Nothing playing"
                color: sheet.cHi
                font.family: sheet.fUI; font.pixelSize: 19; font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: {
                    var a = (island && island.artist) ? island.artist : "—"
                    var b = (island && island.album) ? island.album : ""
                    return b ? a + "  ·  " + b : a
                }
                color: sheet.cLo
                font.family: sheet.fUI; font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        // ---------------------------------------------------------- seek
        Item {
            id: seek
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            readonly property real barWidth: 3.2
            readonly property int barCount: Math.max(2, Math.floor(width / (barWidth * 2.2)))
            readonly property real trackLength: island ? island.mediaLength : 0
            readonly property bool seekable: trackLength > 0 && island && island.canSeek

            property real scrubRatio: -1
            readonly property real progress: scrubRatio >= 0
                ? scrubRatio
                : (trackLength > 0
                   ? Math.max(0, Math.min(1, island.smoothPosition / trackLength))
                   : 0)

            function ratioAt(x) { return Math.max(0, Math.min(1, x / Math.max(1, width))) }

            property real phase: 0
            NumberAnimation on phase {
                running: sheet.playing && island && island.panelOpen
                loops: Animation.Infinite
                from: 0; to: Math.PI * 2; duration: 1400
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: (width - seek.barCount * seek.barWidth) / Math.max(1, seek.barCount - 1)
                Repeater {
                    model: seek.barCount
                    Rectangle {
                        required property int index
                        width: seek.barWidth
                        radius: seek.barWidth / 2
                        readonly property bool past: index < seek.progress * seek.barCount
                        height: Math.max(3, 5 + 15 * Math.abs(Math.sin(index * 0.55
                                    + (sheet.playing ? seek.phase : 0))))
                        anchors.verticalCenter: parent.verticalCenter
                        color: past ? sheet.cHi : sheet.cBor
                        Behavior on height { NumberAnimation { duration: 180 } }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: seek.seekable
                preventStealing: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: (m) => seek.scrubRatio = seek.ratioAt(m.x)
                onPositionChanged: (m) => { if (pressed) seek.scrubRatio = seek.ratioAt(m.x) }
                onReleased: (m) => {
                    island.seekTo(seek.ratioAt(m.x) * seek.trackLength)
                    seek.scrubRatio = -1
                }
                onCanceled: seek.scrubRatio = -1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: island ? island.fmtTime(seek.progress * seek.trackLength) : "0:00"
                color: sheet.cLo; font.family: sheet.fUI; font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: island ? island.fmtTime(island.mediaLength) : "0:00"
                color: sheet.cLo; font.family: sheet.fUI; font.pixelSize: 10
            }
        }

        // ---------------------------------------------------------- transport
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 57.2
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 41.6; Layout.preferredHeight: 41.6
                Layout.alignment: Qt.AlignVCenter
                radius: 20.8
                readonly property bool on: island && island.shuffleStatus === Mpris.ShuffleStatus.On
                color: on ? sheet.cCard2 : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
                Kirigami.Icon {
                    anchors.centerIn: parent; width: 16.9; height: 16.9
                    source: "media-playlist-shuffle"; isMask: true
                    color: parent.on ? sheet.cHi : sheet.cDis
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.toggleShuffle()
                }
            }

            Item { Layout.fillWidth: true }

            Kirigami.Icon {
                Layout.preferredWidth: 23.4; Layout.preferredHeight: 23.4
                Layout.alignment: Qt.AlignVCenter
                source: "media-skip-backward"; isMask: true
                color: (island && island.canGoPrev) ? sheet.cHi : sheet.cDis
                MouseArea {
                    anchors.fill: parent; anchors.margins: -9
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (sheet.player) sheet.player.Previous()
                }
            }

            Item { Layout.preferredWidth: 26 }

            Rectangle {
                Layout.preferredWidth: 57.2; Layout.preferredHeight: 57.2
                Layout.alignment: Qt.AlignVCenter
                radius: 28.6
                color: sheet.cHi
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 23.4; height: 23.4
                    source: sheet.playing ? "media-playback-pause" : "media-playback-start"
                    isMask: true; color: sheet.cBg
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (sheet.player) sheet.player.PlayPause()
                }
            }

            Item { Layout.preferredWidth: 26 }

            Kirigami.Icon {
                Layout.preferredWidth: 23.4; Layout.preferredHeight: 23.4
                Layout.alignment: Qt.AlignVCenter
                source: "media-skip-forward"; isMask: true
                color: (island && island.canGoNext) ? sheet.cHi : sheet.cDis
                MouseArea {
                    anchors.fill: parent; anchors.margins: -9
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (sheet.player) sheet.player.Next()
                }
            }

            Item { Layout.fillWidth: true }

            // repeat: off -> playlist -> track
            Rectangle {
                Layout.preferredWidth: 41.6; Layout.preferredHeight: 41.6
                Layout.alignment: Qt.AlignVCenter
                radius: 20.8
                readonly property bool on: island && island.loopStatus !== Mpris.LoopStatus.None
                                           && island.loopStatus !== Mpris.LoopStatus.Unknown
                color: on ? sheet.cCard2 : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
                Kirigami.Icon {
                    anchors.centerIn: parent; width: 16.9; height: 16.9
                    source: (island && island.loopStatus === Mpris.LoopStatus.Track)
                            ? "media-playlist-repeat-song" : "media-playlist-repeat"
                    isMask: true
                    color: parent.on ? sheet.cHi : sheet.cDis
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.cycleLoop()
                }
            }
        }

        // ---------------------------------------------------------- volume
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 49.4
            radius: height / 2
            color: sheet.cCard
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18.2
                anchors.rightMargin: 18.2
                spacing: 13
                Kirigami.Icon {
                    source: (island && island.muted) ? "audio-volume-muted" : "audio-volume-high"
                    isMask: true; color: sheet.cHi
                    Layout.preferredWidth: 15.6; Layout.preferredHeight: 15.6
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 15.6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 3.9; radius: 2
                        color: sheet.cBor
                        Rectangle {
                            width: parent.width * (island ? island.volPct : 0) / 100
                            height: parent.height; radius: 2
                            color: sheet.cHi
                        }
                    }
                    Rectangle {
                        width: 11.7; height: 11.7; radius: 5.85
                        color: sheet.cHi
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - 11.7,
                            parent.width * (island ? island.volPct : 0) / 100 - 5.85))
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -13
                        anchors.bottomMargin: -13
                        onPressed: (m) => island.setVolume(m.x / width * 100)
                        onPositionChanged: (m) => { if (pressed) island.setVolume(m.x / width * 100) }
                    }
                }
                Text {
                    text: (island ? island.volPct : 0) + "%"
                    color: sheet.cLo
                    font.family: sheet.fUI; font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 33.8
                }
            }
        }
    }
}
