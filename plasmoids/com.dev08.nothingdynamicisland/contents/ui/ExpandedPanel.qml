import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Item {
    id: panel
    property var island

    readonly property color cBg:   island ? island.islandBg : "#0b0b0c"
    readonly property color cCard: island ? island.cardBg   : "#1b1b1d"
    readonly property color cHi:   island ? island.textHi   : "#ffffff"
    readonly property color cLo:   island ? island.textLo   : "#999999"
    readonly property color cRed:  island ? island.nRed     : "#d71921"
    readonly property string fUI:  island ? island.fontUI   : "sans"
    readonly property string fMono: island ? island.fontMono : "monospace"
    readonly property color cDis:  island ? island.textDis  : "#666666"
    readonly property color cBor:  island ? island.cBorder  : "#333333"

    // A labelled meter: name, bar, percentage, optional temperature.
    component StatRow: RowLayout {
        id: statRow
        property string label: ""
        property int value: 0
        property int temperature: -1

        Layout.fillWidth: true
        spacing: 7.8
        Text {
            text: statRow.label
            color: panel.cLo
            font.family: panel.fMono; font.pixelSize: 10; font.letterSpacing: 0.5
            Layout.preferredWidth: 31.2
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3.9
            radius: 2
            color: panel.cBor
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, statRow.value)) / 100
                height: parent.height; radius: 2
                color: panel.cHi
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
        Text {
            text: statRow.value + "%"
            color: panel.cHi
            font.family: panel.fUI; font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 32.5
        }
        Text {
            text: statRow.temperature >= 0 ? statRow.temperature + "\u00b0" : ""
            color: statRow.temperature >= 80 ? panel.cRed : panel.cLo
            font.family: panel.fUI; font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 26
        }
    }

    // Staged reveal: rows tick in top-to-bottom. Percussive, ease-out, no spring.
    property real reveal: 0
    function stage(i) { return Math.max(0, Math.min(1, (reveal - i * 0.07) * 5)) }
    NumberAnimation on reveal {
        running: true
        from: 0; to: 1; duration: 300
        easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    }
    onVisibleChanged: if (visible) { reveal = 0; revealAgain.restart() }
    NumberAnimation {
        id: revealAgain
        target: panel; property: "reveal"
        from: 0; to: 1; duration: 300
        easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    }

    Layout.minimumWidth: 500
    Layout.minimumHeight: 404
    Layout.preferredWidth: 500
    Layout.preferredHeight: 404
    implicitWidth: 500
    implicitHeight: 404

    Rectangle {
        anchors.fill: parent
        radius: 28.6
        color: panel.cBg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16.9
            spacing: 9.1

            // ---------------------------------------------- header
            RowLayout {
                Layout.preferredHeight: 44.2
                Layout.fillHeight: false
                opacity: panel.stage(0)
                Layout.fillWidth: true
                spacing: 13

                Row {
                    spacing: 3.9
                    Text {
                        text: panel.island ? panel.island.timeText : "--:--"
                        color: panel.cHi
                        font.family: panel.fUI
                        font.pixelSize: 35
                        font.weight: Font.Bold
                    }
                    Text {
                        text: panel.island ? panel.island.secText : "--"
                        color: panel.cLo
                        font.family: panel.fUI
                        font.pixelSize: 13
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3.9
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Text {
                        text: panel.island ? panel.island.dateText : ""
                        color: panel.cHi
                        font.family: panel.fMono
                        font.pixelSize: 13
                        font.letterSpacing: 0.6
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: "CALENDAR"
                        color: panel.cLo
                        font.family: panel.fMono
                        font.pixelSize: 10
                        font.letterSpacing: 0.8
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            // ---------------------------------------------- connectivity + sound
            RowLayout {
                Layout.preferredHeight: 49.4
                Layout.fillHeight: false
                opacity: panel.stage(1)
                Layout.fillWidth: true
                spacing: 9.1

                // network
                Rectangle {
                    Layout.preferredWidth: 145.6
                    Layout.preferredHeight: 49.4
                    radius: height / 2
                    color: panel.cCard
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7.8
                        anchors.rightMargin: 11.7
                        spacing: 7.8
                        Rectangle {
                            Layout.preferredWidth: 33.8; Layout.preferredHeight: 33.8
                            radius: height / 2
                            color: panel.cHi
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18.2; height: 18.2
                                source: panel.island && panel.island.netType.indexOf("wireless") >= 0
                                        ? "network-wireless" : "network-wired"
                                isMask: true
                                color: panel.cBg
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                text: panel.island ? panel.island.netName : ""
                                color: panel.cHi
                                font.family: panel.fUI; font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: (panel.island && panel.island.netName !== "Offline") ? "CONNECTED" : "OFFLINE"
                                color: panel.cLo
                                font.family: panel.fMono; font.pixelSize: 10; font.letterSpacing: 0.5
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.island.exec("plasma-open-settings kcm_networkmanagement")
                    }
                }

                // bluetooth
                Rectangle {
                    Layout.preferredWidth: 158.6
                    Layout.preferredHeight: 49.4
                    radius: height / 2
                    color: panel.cCard
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7.8
                        anchors.rightMargin: 11.7
                        spacing: 7.8
                        Rectangle {
                            Layout.preferredWidth: 33.8; Layout.preferredHeight: 33.8
                            radius: height / 2
                            color: (panel.island && panel.island.btName !== "Not connected") ? panel.cHi : panel.cBor
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18.2; height: 18.2
                                source: "preferences-system-bluetooth"
                                isMask: true
                                color: (panel.island && panel.island.btName !== "Not connected") ? panel.cBg : panel.cLo
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                text: "Bluetooth"
                                color: panel.cHi
                                font.family: panel.fUI; font.pixelSize: 13; font.weight: Font.DemiBold
                            }
                            Text {
                                text: panel.island ? panel.island.btName : ""
                                color: panel.cLo
                                font.family: panel.fUI; font.pixelSize: 10; font.letterSpacing: 0.3
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.island.exec("plasma-open-settings kcm_bluetooth")
                    }
                }

                // sound
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 49.4
                    radius: height / 2
                    color: panel.cCard
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14.3
                        anchors.rightMargin: 14.3
                        anchors.topMargin: 7.8
                        anchors.bottomMargin: 7.8
                        spacing: 2.6
                        Text {
                            text: "SOUND"
                            color: panel.cLo
                            font.family: panel.fMono; font.pixelSize: 10; font.letterSpacing: 0.8
                        }
                        RowLayout {
                            spacing: 7.8
                            Layout.fillWidth: true
                            Kirigami.Icon {
                                source: (panel.island && panel.island.muted) ? "audio-volume-muted" : "audio-volume-high"
                                isMask: true; color: panel.cHi
                                Layout.preferredWidth: 14.3; Layout.preferredHeight: 14.3
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 15.6
                                Rectangle {
                                    id: volTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width; height: 3.9; radius: 2
                                    color: panel.cBor
                                    Rectangle {
                                        width: parent.width * (panel.island ? panel.island.volPct : 0) / 100
                                        height: parent.height; radius: 2
                                        color: panel.cHi
                                    }
                                }
                                Rectangle {
                                    width: 10.4; height: 10.4; radius: 5.2
                                    color: panel.cHi
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - 8,
                                        parent.width * (panel.island ? panel.island.volPct : 0) / 100 - 4))
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onPressed: (m) => panel.island.setVolume(m.x / width * 100)
                                    onPositionChanged: (m) => { if (pressed) panel.island.setVolume(m.x / width * 100) }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- media
            Rectangle {
                Layout.fillHeight: false
                opacity: panel.stage(2)
                Layout.fillWidth: true
                Layout.preferredHeight: 109.2
                radius: 16
                color: panel.cCard

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 11.7
                    spacing: 5.2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10.4

                        Rectangle {
                            Layout.preferredWidth: 39; Layout.preferredHeight: 39
                            radius: 7.8
                            color: panel.cCard
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: panel.island ? panel.island.albumArt : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                asynchronous: true
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18.2; height: 18.2
                                source: "media-playback-start"
                                isMask: true; color: panel.cLo
                                visible: !(panel.island && panel.island.albumArt)
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                text: (panel.island && panel.island.track) ? panel.island.track : "Nothing playing"
                                color: panel.cHi
                                font.family: panel.fUI; font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: (panel.island && panel.island.artist) ? panel.island.artist : "—"
                                color: panel.cLo
                                font.family: panel.fUI; font.pixelSize: 10
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }

                        Row {
                            spacing: 9.1
                            Layout.alignment: Qt.AlignVCenter
                            Kirigami.Icon {
                                width: 16.9; height: 16.9
                                source: "media-skip-backward"; isMask: true; color: panel.cHi
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    onClicked: if (panel.island.player) panel.island.player.Previous()
                                }
                            }
                            Rectangle {
                                width: 31.2; height: 31.2; radius: 15.6; color: panel.cHi
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 15.6; height: 15.6
                                    source: (panel.island && panel.island.isPlaying)
                                            ? "media-playback-pause" : "media-playback-start"
                                    isMask: true; color: panel.cBg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: if (panel.island.player) panel.island.player.PlayPause()
                                }
                            }
                            Kirigami.Icon {
                                width: 16.9; height: 16.9
                                source: "media-skip-forward"; isMask: true; color: panel.cHi
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    onClicked: if (panel.island.player) panel.island.player.Next()
                                }
                            }
                        }
                    }

                    // waveform -- doubles as the seek bar
                    Item {
                        id: seekBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 19.5

                        readonly property real barWidth: 2.6
                        readonly property int barCount: Math.max(2, Math.floor(width / (barWidth * 2)))
                        readonly property real trackLength: panel.island ? panel.island.mediaLength : 0
                        readonly property bool seekable: trackLength > 0 && panel.island.canSeek

                        // >= 0 only while a drag is in flight, so the bar follows the pointer
                        // instead of snapping back on the next player update.
                        property real scrubRatio: -1
                        readonly property real progress: scrubRatio >= 0
                            ? scrubRatio
                            : (trackLength > 0
                               ? Math.max(0, Math.min(1, panel.island.mediaPosition / trackLength))
                               : 0)

                        function ratioAt(x) {
                            return Math.max(0, Math.min(1, x / Math.max(1, width)))
                        }

                        property real phase: 0
                        NumberAnimation on phase {
                            running: panel.island ? panel.island.isPlaying : false
                            loops: Animation.Infinite
                            from: 0; to: Math.PI * 2; duration: 1400
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: (width - seekBar.barCount * seekBar.barWidth)
                                     / Math.max(1, seekBar.barCount - 1)
                            Repeater {
                                model: seekBar.barCount
                                Rectangle {
                                    width: seekBar.barWidth
                                    radius: seekBar.barWidth / 2
                                    readonly property bool past:
                                        index < seekBar.progress * seekBar.barCount
                                    height: {
                                        var base = 3 + 9 * Math.abs(Math.sin(index * 0.7
                                                 + (panel.island && panel.island.isPlaying
                                                    ? seekBar.phase : 0)))
                                        return Math.max(2, base)
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: past ? panel.cHi : panel.cBor
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            enabled: seekBar.seekable
                            preventStealing: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: (m) => seekBar.scrubRatio = seekBar.ratioAt(m.x)
                            onPositionChanged: (m) => {
                                if (pressed) {
                                    seekBar.scrubRatio = seekBar.ratioAt(m.x)
                                }
                            }
                            onReleased: (m) => {
                                panel.island.seekTo(seekBar.ratioAt(m.x) * seekBar.trackLength)
                                seekBar.scrubRatio = -1
                            }
                            onCanceled: seekBar.scrubRatio = -1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: panel.island
                                  ? panel.island.fmtTime(seekBar.progress * seekBar.trackLength)
                                  : "0:00"
                            color: panel.cLo; font.family: panel.fUI; font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: panel.island ? panel.island.fmtTime(panel.island.mediaLength) : "0:00"
                            color: panel.cLo; font.family: panel.fUI; font.pixelSize: 10
                        }
                    }
                }
            }

            // ---------------------------------------------- stopwatch + stats
            RowLayout {
                Layout.preferredHeight: 83.2
                Layout.fillHeight: false
                opacity: panel.stage(3)
                Layout.fillWidth: true
                spacing: 9.1

                Rectangle {
                    Layout.preferredWidth: 166.4
                    Layout.fillHeight: true
                    Layout.maximumHeight: 83.2
                    radius: 15.6
                    color: panel.cCard
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11.7
                        spacing: 3.9
                        RowLayout {
                            spacing: 6.5
                            Rectangle {
                                Layout.preferredWidth: 19.5; Layout.preferredHeight: 19.5
                                radius: 9.8
                                color: (panel.island && panel.island.swRunning) ? panel.cRed : panel.cBor
                                SequentialAnimation on opacity {
                                    running: panel.island ? panel.island.swRunning : false
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                                    NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] }
                                }
                                onVisibleChanged: if (!visible) opacity = 1
                                Kirigami.Icon {
                                    anchors.centerIn: parent; width: 10.4; height: 10.4
                                    source: (panel.island && panel.island.swRunning)
                                            ? "media-playback-pause" : "media-playback-start"
                                    isMask: true; color: panel.cHi
                                }
                            }
                            Text {
                                text: "STOPWATCH"
                                color: panel.cLo
                                font.family: panel.fMono; font.pixelSize: 10; font.letterSpacing: 0.7
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            text: panel.island ? panel.island.swText : "00:00"
                            color: panel.cHi
                            font.family: panel.fUI; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.island.swRunning = !panel.island.swRunning
                        onPressAndHold: { panel.island.swRunning = false; panel.island.swSeconds = 0 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumHeight: 83.2
                    radius: 15.6
                    color: panel.cCard
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11.7
                        spacing: 6.5
                        // One standing row per stat, bound to the live value. Feeding a
                        // Repeater a JS array of readings rebuilt the whole array on every
                        // poll, so all three delegates were destroyed and recreated -- the
                        // bars snapped to the new width instead of animating to it.
                        StatRow {
                            label: "CPU"
                            value: panel.island ? panel.island.cpuPct : 0
                            temperature: panel.island ? panel.island.tempC : -1
                        }
                        StatRow {
                            label: "RAM"
                            value: panel.island ? panel.island.memPct : 0
                        }
                        StatRow {
                            label: "DISP"
                            value: panel.island ? panel.island.brightPct : 0
                        }
                    }
                }
            }

            // ---------------------------------------------- toggles
            RowLayout {
                Layout.fillHeight: false
                opacity: panel.stage(4)
                Layout.fillWidth: true
                Layout.preferredHeight: 41.6
                spacing: 9.1

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: height / 2
                    color: panel.cCard
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15.6
                        anchors.rightMargin: 7.8
                        spacing: 9.1
                        Kirigami.Icon {
                            source: (panel.island && panel.island.caffeine)
                                    ? "caffeine-cup-full" : "caffeine-cup-empty"
                            isMask: true
                            color: (panel.island && panel.island.caffeine) ? panel.cBg : panel.cHi
                            Layout.preferredWidth: 15.6; Layout.preferredHeight: 15.6
                        }
                        Text {
                            text: "CAFFEINE MODE"
                            color: (panel.island && panel.island.caffeine) ? panel.cBg : panel.cHi
                            font.family: panel.fMono; font.pixelSize: 10; font.letterSpacing: 0.8
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 41.6; Layout.preferredHeight: 23.4
                            radius: 11.7
                            color: (panel.island && panel.island.caffeine) ? panel.cHi : panel.cBor
                            Rectangle {
                                width: 18.2; height: 18.2; radius: 9.1
                                y: 2
                                x: (panel.island && panel.island.caffeine) ? parent.width - 16 : 2
                                color: (panel.island && panel.island.caffeine) ? panel.cBg : panel.cHi
                                Behavior on x { NumberAnimation { duration: 140 } }
                            }
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    MouseArea { anchors.fill: parent; onClicked: panel.island.toggleCaffeine() }
                }

                Rectangle {
                    Layout.preferredWidth: 49.4
                    Layout.fillHeight: true
                    radius: height / 2
                    color: panel.cCard
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16.9; height: 16.9
                        source: "system-lock-screen"; isMask: true; color: panel.cHi
                    }
                    MouseArea { anchors.fill: parent; onClicked: panel.island.lockScreen() }
                }

                Rectangle {
                    Layout.preferredWidth: 49.4
                    Layout.fillHeight: true
                    radius: height / 2
                    color: (panel.island && panel.island.dnd) ? panel.cRed : panel.cCard
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16.9; height: 16.9
                        source: "notifications"; isMask: true; color: panel.cHi
                    }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    MouseArea { anchors.fill: parent; onClicked: panel.island.toggleDnd() }
                }
            }

            // soak up any extra height so no row stretches out of proportion
            Item { Layout.fillHeight: true; Layout.fillWidth: true }
        }
    }
}
