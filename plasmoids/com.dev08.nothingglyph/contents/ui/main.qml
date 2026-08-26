import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import "Glyph.js" as Glyph

// A dot-matrix character that reacts to what the machine is doing.
//
// Every input here is event-driven -- MPRIS for playback, PowerDevil for the
// battery, and a one-minute tick for the clock. Nothing polls a subprocess: this
// widget sits on the desktop all day, and the island's own audit showed how
// quickly a 2-second shell poll turns into 4% of a core.
PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Matched to the jaxparrow07 widgets sharing this grid: they inset their card
    // by 10, round it at 20, and fill with #1a1a1a. Anything else and this cell
    // reads as bigger and a different black than the ones beside it.
    readonly property color cardBg: "#1a1a1a"
    readonly property int cardInset: 10
    readonly property int cardRadius: 20
    // They also draw the card at 95% opacity, which over this wallpaper lifts
    // #1a1a1a to a measured 34,34,34. Matching the opacity rather than
    // hardcoding #222222 keeps it correct if the wallpaper ever changes.
    readonly property real cardOpacity: 0.95
    readonly property color dotOn:  "#ffffff"
    readonly property color cLo:    "#999999"
    readonly property color cDis:   "#666666"
    readonly property color nRed:   "#d71921"
    readonly property string fMono: "NType 82 Mono"

    // ---------------------------------------------------------------- inputs
    Mpris.Mpris2Model { id: mpris }
    readonly property bool musicPlaying:
        mpris.currentPlayer !== null && mpris.currentPlayer !== undefined
        && mpris.currentPlayer.playbackStatus === Mpris.PlaybackStatus.Playing

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }
    readonly property int  batteryPct: (pm.data["Battery"] || {})["Percent"] || 0
    readonly property bool hasBattery: ((pm.data["Battery"] || {})["Has Battery"]) === true
    readonly property bool onAC: ((pm.data["AC Adapter"] || {})["Plugged in"]) === true

    property int hour: new Date().getHours()
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.hour = new Date().getHours()
    }
    readonly property bool nightTime: root.hour >= 23 || root.hour < 6

    // ---------------------------------------------------------------- state
    // Order is a priority list, not a switch. Music beats charging on purpose:
    // it is the thing you are actually doing, the charger is just plugged in.
    readonly property string liveState: {
        if (root.hasBattery && root.batteryPct <= 15 && !root.onAC) return "low"
        if (root.musicPlaying) return "music"
        if (root.onAC && root.hasBattery && root.batteryPct < 100) return "charge"
        if (root.nightTime) return "sleep"
        return "idle"
    }

    // Tapping the widget previews the other poses, then hands control back.
    property string preview: ""
    property int previewIdx: 0
    readonly property var previewOrder: ["idle", "music", "charge", "low", "sleep"]
    Timer {
        id: previewTimer
        interval: 4000
        onTriggered: root.preview = ""
    }
    function cyclePreview() {
        root.previewIdx = (root.previewIdx + 1) % root.previewOrder.length
        root.preview = root.previewOrder[root.previewIdx]
        previewTimer.restart()
    }

    readonly property string state_: root.preview !== "" ? root.preview : root.liveState

    readonly property string caption: {
        switch (root.state_) {
        case "music":  return "VIBING"
        case "charge": return "CHARGING"
        case "low":    return "LOW BATTERY"
        case "sleep":  return "ZZZ"
        default:       return "HELLO"
        }
    }

    // ---------------------------------------------------------------- frames
    property int tick: 0
    // Only music and sleep actually animate; idle needs a slow beat for the
    // blink, and the other two are still. One timer covers all of it.
    Timer {
        interval: 380
        repeat: true
        running: root.visible
        onTriggered: root.tick++
    }
    readonly property var lit: Glyph.build(root.state_, root.tick)

    // ---------------------------------------------------------------- view
    fullRepresentation: Item {
        id: face
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: root.cardInset
            radius: root.cardRadius
            color: root.cardBg
            opacity: root.cardOpacity

            // 16 columns of dots, sized off the card so it scales with the cell.
            // Height budget leaves room for the caption strip underneath.
            readonly property real pitch: Math.max(3, Math.floor(Math.min(width, height - 26) * 0.94 / 16))
            readonly property real dot: Math.max(2, Math.round(pitch * 0.68))
            readonly property real gridSize: 16 * dot + 15 * (pitch - dot)

            Grid {
                id: grid
                columns: 16
                rows: 16
                spacing: card.pitch - card.dot
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round((card.height - 22 - card.gridSize) / 2)

                Repeater {
                    model: 256
                    Rectangle {
                        required property int index
                        width: card.dot
                        height: card.dot
                        radius: width / 2
                        color: (root.state_ === "low" && root.lit[index]) ? root.nRed : root.dotOn
                        // Off dots are not drawn at all: the dot-matrix clock and
                        // the weather glyph next door light dots on black, they do
                        // not show an unlit grid.
                        opacity: root.lit[index] ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.07)
                text: root.caption
                color: root.state_ === "low" ? root.nRed : root.cDis
                font.family: root.fMono
                font.pixelSize: Math.max(8, Math.round(parent.height * 0.052))
                font.letterSpacing: 1.0
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cyclePreview()
            }
        }
    }

    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    toolTipMainText: "Glyph"
    toolTipSubText: root.caption + (root.preview !== "" ? " (preview — tap to cycle)" : "")
}
