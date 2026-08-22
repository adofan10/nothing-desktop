import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// Nothing design rules applied here:
//   - grayscale IS the hierarchy (100 / 60 / 40), red is an interrupt only
//   - type does the heavy lifting: one focal element (the clock)
//   - motion is percussive: short ease-out, no spring, no bounce
Item {
    id: pill
    property var island

    readonly property int  pillH: 38
    readonly property real pillW: Math.max(170, (row.implicitWidth || 0) + 38)

    implicitHeight: pillH
    implicitWidth:  pillW

    // Plasma sizes panel applets from the Layout attached properties.
    Layout.preferredWidth:  pillW
    Layout.minimumWidth:    pillW
    Layout.maximumWidth:    pillW
    Layout.preferredHeight: pillH
    Layout.fillWidth:  false
    Layout.fillHeight: false

    // ---- grayscale hierarchy ----
    readonly property color cDisplay: island ? island.textHi  : "#ffffff"
    readonly property color cPrimary: island ? island.textPri : "#e8e8e8"
    readonly property color cSecond:  island ? island.textLo  : "#999999"
    readonly property color cDim:     island ? island.textDis : "#666666"
    readonly property color cRed:     island ? island.nRed : "#d71921" // interrupt ONLY

    readonly property bool batteryUrgent:
        island ? (island.batteryPct <= 15 && !island.onAC) : false

    // ---- virtual desktops ----
    TaskManager.VirtualDesktopInfo { id: vdi }
    readonly property int desktopCount: vdi.numberOfDesktops || 1
    readonly property int currentIndex: {
        var ids = vdi.desktopIds || []
        for (var i = 0; i < ids.length; ++i)
            if (ids[i] === vdi.currentDesktop) return i
        return 0
    }

    // ---- reveal: the shell expands from a seed, then contents tick in left-to-right ----
    property real reveal: 0

    function playReveal() { revealSeq.restart() }

    // Nothing motion: "prefer opacity over position -- elements fade, don't slide".
    // The shell no longer widens; it fades in, contents follow.
    NumberAnimation {
        id: revealSeq
        target: pill; property: "reveal"
        from: 0; to: 1; duration: 300
        // iOS's "smooth" deceleration curve. Strong ease-out, still no overshoot,
        // so it reads like the iOS volume HUD without violating Nothing's no-bounce rule.
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.32, 0.72, 0.0, 1.0, 1.0, 1.0]
    }

    Component.onCompleted: {
        if (pill.island) pill.island.anchorItem = pill   // anchor for the popup dialog
        playReveal()
    }
    onVisibleChanged: {
        if (visible) playReveal()
        else { reveal = 0 }   // reset so the next appearance replays
    }

    Rectangle {
        id: body
        // Fill the applet. Do NOT bind width to pillW: pillW is derived from `row`,
        // which lives inside this Rectangle, and that circular dependency makes QML
        // drop the binding -- Plasma then sizes the applet as a 42x42 square.
        anchors.fill: parent
        radius: height / 2
        color: pill.island ? pill.island.islandBg : "#000000"
        clip: true
        // iOS-HUD style entrance: fade + a subtle settle, no overshoot.
        opacity: pill.reveal
        scale: 0.94 + 0.06 * pill.reveal

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 12

            // ============================================ virtual desktop pager
            Row {
                id: pager
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: pill.desktopCount
                    Rectangle {
                        readonly property bool active: index === pill.currentIndex
                        // sequential tick-in, 55ms apart
                        opacity: Math.max(0, Math.min(1, (pill.reveal - index * 0.09) * 5))
                        width:  active ? 22 : 6
                        height: 6
                        radius: 3
                        color: active ? pill.cDisplay : pill.cDim
                        anchors.verticalCenter: parent.verticalCenter

                        // the morph: current desktop stretches, others contract
                        Behavior on width {
                            NumberAnimation { duration: 190; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 190; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ids = vdi.desktopIds || []
                                if (index < ids.length) vdi.requestActivate(ids[index])
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredWidth: 9 }

            // ============================================ brightness (tertiary)
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                opacity: Math.max(0, Math.min(1, (pill.reveal - 0.12) * 4))
                Kirigami.Icon {
                    source: "brightness-high"; isMask: true; color: pill.cSecond
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: (pill.island ? pill.island.brightPct : 0) + "%"
                    color: pill.cSecond
                    font.family: pill.island ? pill.island.fontUI : "sans"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.preferredWidth: 12 }

            // ============================================ clock — the focal point
            Text {
                id: clock
                text: pill.island ? pill.island.timeText : "--:--"
                color: pill.cDisplay
                font.family: pill.island ? pill.island.fontUI : "sans"
                font.pixelSize: 19
                font.weight: Font.Bold
                font.letterSpacing: 0.4
                Layout.alignment: Qt.AlignVCenter
                opacity: Math.max(0, Math.min(1, (pill.reveal - 0.2) * 4))

                // percussive tick: a single crisp step on the minute, no easing flourish
                property string prev: clock.text
                // qualify with the id -- a bare `text` here picks up the deprecated
                // injected signal parameter instead of the property
                onTextChanged: {
                    if (clock.text !== clock.prev) { clock.prev = clock.text; tick.restart() }
                }
                SequentialAnimation {
                    id: tick
                    NumberAnimation { target: clock; property: "opacity"; to: 0.45; duration: 60 }
                    NumberAnimation { target: clock; property: "opacity"; to: 1.0;  duration: 110
                                      easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                }
            }

            Item { Layout.preferredWidth: 12 }

            // ============================================ volume (tertiary)
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                opacity: Math.max(0, Math.min(1, (pill.reveal - 0.28) * 4))
                Kirigami.Icon {
                    source: (pill.island && pill.island.muted) ? "audio-volume-muted" : "audio-volume-high"
                    isMask: true
                    color: (pill.island && pill.island.muted) ? pill.cDim : pill.cSecond
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: pill.island ? pill.island.volPct : 0
                    color: pill.cSecond
                    font.family: pill.island ? pill.island.fontUI : "sans"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.preferredWidth: 9 }

            // ============================================ battery
            Row {
                spacing: 7
                Layout.alignment: Qt.AlignVCenter
                opacity: Math.max(0, Math.min(1, (pill.reveal - 0.36) * 4))

                Item {
                    width: 27; height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        id: shell
                        width: 23; height: 13; radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        border.color: pill.batteryUrgent ? pill.cRed : pill.cSecond
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                            width: Math.max(2, (parent.width - 4) * (pill.island ? pill.island.batteryPct : 0) / 100)
                            radius: 1
                            color: pill.batteryUrgent ? pill.cRed : pill.cPrimary
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                    Rectangle {
                        anchors { left: shell.right; leftMargin: 1; verticalCenter: shell.verticalCenter }
                        width: 2; height: 6; radius: 1
                        color: pill.batteryUrgent ? pill.cRed : pill.cSecond
                    }
                    // charging bolt: a state, not decoration
                    Rectangle {
                        visible: pill.island ? pill.island.onAC : false
                        anchors.centerIn: shell
                        width: 3; height: 10
                        color: pill.cDisplay
                        rotation: 22
                        radius: 1
                    }
                }

                Text {
                    text: pill.island ? pill.island.batteryPct : 0
                    color: pill.batteryUrgent ? pill.cRed : pill.cSecond
                    font.family: pill.island ? pill.island.fontUI : "sans"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: pill.island.togglePanel(pill)
    }
}
