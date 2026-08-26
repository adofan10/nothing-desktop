import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

// The island's Bluetooth picker: every known and in-range device, tap to connect.
//
// BluezQt hands us live Device objects, so connect/disconnect are direct calls.
// Pairing is not exposed to QML, so a new device goes through scripts/bt-pair.sh
// -- and because that talks to org.bluez rather than starting its own agent,
// bluedevil's session agent still shows the PIN or confirmation dialog.
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
    readonly property color cRed:   island ? island.nRed     : "#d71921"
    readonly property string fUI:   island ? island.fontUI   : "sans"
    readonly property string fMono: island ? island.fontMono : "monospace"

    // BluezQt.Manager is a singleton that spins up a BlueZ client the moment it
    // is touched, so it is touched here -- inside ExpandedPanel's Loader -- and
    // nowhere on the island itself. Close the island and BlueZ is left alone.
    BluezQt.DevicesModel { id: btDevicesModel }

    property string btError: ""

    readonly property var adapter: BluezQt.Manager.usableAdapter
    readonly property bool powered: adapter ? adapter.powered : false
    readonly property bool discovering: adapter ? adapter.discovering : false

    // Devices we have asked BlueZ to pair, so a row can say so while it happens.
    property var pairing: ({})

    function setPairing(ubi, on) {
        var m = sheet.pairing
        if (on) m[ubi] = true; else delete m[ubi]
        sheet.pairing = m      // reassign: QML does not see in-place mutation
    }

    function act(dev) {
        if (!dev) return
        sheet.btError = ""
        if (dev.connected) {
            dev.disconnectFromDevice()
        } else if (dev.paired) {
            dev.connectToDevice()
        } else {
            sheet.setPairing(dev.ubi, true)
            island.btPair(dev.ubi)
        }
    }

    // Discovery costs radio time, so it runs only while this sheet is on screen.
    onVisibleChanged: {
        if (!sheet.adapter) return
        if (visible && sheet.powered) sheet.adapter.startDiscovery()
        else if (sheet.discovering) sheet.adapter.stopDiscovery()
    }
    Component.onCompleted: if (sheet.adapter && sheet.powered) sheet.adapter.startDiscovery()
    Component.onDestruction: if (sheet.adapter && sheet.discovering) sheet.adapter.stopDiscovery()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16.9
        spacing: 10.4

        // ---- header
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
                    text: "BLUETOOTH"
                    color: sheet.cHi
                    font.family: sheet.fMono; font.pixelSize: 15; font.letterSpacing: 1.2
                }
                Text {
                    text: !sheet.adapter ? "NO ADAPTER"
                          : !sheet.powered ? "RADIO OFF"
                          : sheet.discovering ? "SCANNING…"
                          : "READY"
                    color: sheet.cLo
                    font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.6
                }
            }

            Rectangle {
                Layout.preferredWidth: 41.6; Layout.preferredHeight: 23.4
                radius: 11.7
                color: sheet.powered ? sheet.cHi : sheet.cBor
                Behavior on color { ColorAnimation { duration: 140 } }
                Rectangle {
                    width: 18.2; height: 18.2; radius: 9.1
                    y: 2
                    x: sheet.powered ? parent.width - 20.2 : 2
                    color: sheet.powered ? sheet.cBg : sheet.cHi
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: sheet.adapter !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BluezQt.Manager.bluetoothBlocked = sheet.powered
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: sheet.cBor }

        Text {
            Layout.fillWidth: true
            visible: sheet.btError !== ""
            text: sheet.btError.toUpperCase()
            color: sheet.cRed
            font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.6
            elide: Text.ElideRight
        }

        // ---- devices
        ListView {
            id: devList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2.6
            model: btDevicesModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: devRow
                required property var model
                readonly property var dev: devRow.model.Device
                readonly property bool isPairing: sheet.pairing[devRow.model.Ubi] === true

                width: devList.width
                height: 46.8

                // The row settles back to its resting state once BlueZ confirms.
                onIsPairingChanged: {}
                Connections {
                    target: devRow.dev
                    function onPairedChanged() {
                        if (devRow.dev && devRow.dev.paired) sheet.setPairing(devRow.model.Ubi, false)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: devHover.hovered || devRow.model.Connected ? sheet.cCard : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11.7
                        anchors.rightMargin: 14.3
                        spacing: 11.7

                        Rectangle {
                            Layout.preferredWidth: 31.2; Layout.preferredHeight: 31.2
                            radius: 15.6
                            color: devRow.model.Connected ? sheet.cHi : sheet.cCard2
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 16.9; height: 16.9
                                source: devRow.model.Icon || "preferences-system-bluetooth"
                                isMask: true
                                color: devRow.model.Connected ? sheet.cBg : sheet.cLo
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                text: devRow.model.FriendlyName || devRow.model.Name || devRow.model.Address
                                color: sheet.cHi
                                font.family: sheet.fUI; font.pixelSize: 13
                                font.weight: devRow.model.Connected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: devRow.isPairing ? "PAIRING…"
                                      : devRow.model.Connected ? "CONNECTED"
                                      : devRow.model.Paired ? "PAIRED"
                                      : "TAP TO PAIR"
                                color: devRow.model.Connected ? sheet.cHi : sheet.cLo
                                font.family: sheet.fMono; font.pixelSize: 9; font.letterSpacing: 0.6
                            }
                        }

                        // battery, when the device reports one -- Nothing shows it as a number
                        Text {
                            visible: devRow.dev && devRow.dev.battery !== null
                                     && devRow.model.Connected
                            text: (devRow.dev && devRow.dev.battery ? devRow.dev.battery.percentage : 0) + "%"
                            color: sheet.cLo
                            font.family: sheet.fUI; font.pixelSize: 11
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            visible: devRow.model.Paired
                            text: devRow.model.Connected ? "×" : "⌫"
                            color: sheet.cDis
                            font.family: sheet.fUI; font.pixelSize: 15
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -7
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (devRow.model.Connected) devRow.dev.disconnectFromDevice()
                                    else island.btForget(devRow.model.Ubi)
                                }
                            }
                        }
                    }

                    HoverHandler { id: devHover }
                    TapHandler { onTapped: sheet.act(devRow.dev) }
                }
            }
        }

        // ---- the escape hatch: BlueZ pairing that needs more than a tap
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 41.6
            radius: height / 2
            color: sheet.cCard
            RowLayout {
                anchors.centerIn: parent
                spacing: 9.1
                Kirigami.Icon {
                    source: "settings-configure"; isMask: true; color: sheet.cLo
                    Layout.preferredWidth: 14.3; Layout.preferredHeight: 14.3
                }
                Text {
                    text: "BLUETOOTH SETTINGS"
                    color: sheet.cHi
                    font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.9
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    island.exec("plasma-open-settings kcm_bluetooth")
                    island.panelOpen = false
                }
            }
        }
    }
}
