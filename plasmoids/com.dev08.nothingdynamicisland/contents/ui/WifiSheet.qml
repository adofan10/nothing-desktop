import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM

// The island's Wi-Fi picker. Two states, never both on screen at once:
//   list  -- every access point in range, tap to join or drop
//   auth  -- one network, one password field (Nothing's own flow: pick, then type)
//
// Joining goes through PlasmaNM.Handler, the same object plasma-nm's applet uses,
// so saved profiles, the secret agent and the connection editor all still apply.
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

    readonly property bool radioOn: island ? island.wifiRadio : true

    // These live here, not on the island: NetworkModel subscribes to every access
    // point's signal-strength updates, and holding it open all day would churn for
    // a sheet that is on screen for seconds at a time. The sheet is built inside
    // ExpandedPanel's Loader, so closing the island tears the whole lot down.
    PlasmaNM.NetworkModel { id: nmModel }
    PlasmaNM.AppletProxyModel { id: nmProxy; sourceModel: nmModel }
    PlasmaNM.Handler { id: nmHandler }

    property string netError: ""
    Connections {
        target: nmHandler
        function onConnectionActivationFailed(connectionPath, message) {
            sheet.netError = message || "Connection failed"
        }
    }

    // 0 = list, 1 = password entry
    property int mode: 0
    property string authSsid: ""
    property string authDevice: ""
    property string authSpecific: ""
    property string authSecurity: ""
    // The SSID we last asked NetworkManager to bring up, so the list can say so.
    property string pendingSsid: ""

    function isPsk(t) {
        return t === PlasmaNM.Enums.StaticWep
            || t === PlasmaNM.Enums.WpaPsk
            || t === PlasmaNM.Enums.Wpa2Psk
            || t === PlasmaNM.Enums.SAE
    }

    function activate(m) {
        sheet.netError = ""
        if (m.ConnectionState === PlasmaNM.Enums.Activated
            || m.ConnectionState === PlasmaNM.Enums.Activating) {
            sheet.pendingSsid = ""
            nmHandler.deactivateConnection(m.ConnectionPath, m.DevicePath)
            return
        }
        sheet.pendingSsid = m.Ssid || m.Name
        if (m.Uuid) {
            // Already a saved profile -- NetworkManager holds the secret.
            nmHandler.activateConnection(m.ConnectionPath, m.DevicePath, m.SpecificPath)
            return
        }
        if (sheet.isPsk(m.SecurityType)) {
            sheet.authSsid     = m.Ssid || m.Name
            sheet.authDevice   = m.DevicePath
            sheet.authSpecific = m.SpecificPath
            sheet.authSecurity = m.SecurityTypeString || ""
            passwordField.text = ""
            sheet.mode = 1
            return
        }
        // Open network, or an enterprise one -- for the latter the kded secret
        // agent puts up the proper dialog, which is more than a pill can ask for.
        nmHandler.addAndActivateConnection(m.DevicePath, m.SpecificPath)
    }

    function join() {
        if (!sheet.authDevice) return
        sheet.netError = ""
        nmHandler.addAndActivateConnection(sheet.authDevice, sheet.authSpecific,
                                                   passwordField.text)
        passwordField.text = ""
        sheet.mode = 0
    }

    // A scan is a request, not a promise: ask on open and keep nudging while the
    // sheet is up, otherwise the list is whatever wpa_supplicant last cached.
    Component.onCompleted: if (sheet.radioOn) nmHandler.requestScan()
    Timer {
        interval: 12000; repeat: true; running: sheet.visible && sheet.radioOn && sheet.mode === 0
        onTriggered: nmHandler.requestScan()
    }

    // ---------------------------------------------------------------- list
    Item {
        anchors.fill: parent
        opacity: sheet.mode === 0 ? 1 : 0
        visible: opacity > 0
        enabled: sheet.mode === 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

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
                        text: "WI-FI"
                        color: sheet.cHi
                        font.family: sheet.fMono; font.pixelSize: 15; font.letterSpacing: 1.2
                    }
                    Text {
                        text: !sheet.radioOn ? "RADIO OFF"
                              : nmHandler.scanning ? "SCANNING…"
                              : (island.netName && island.netName !== "Offline"
                                 ? island.netName.toUpperCase() : "NOT CONNECTED")
                        color: sheet.cLo
                        font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.6
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                // ---- radio toggle
                Rectangle {
                    Layout.preferredWidth: 41.6; Layout.preferredHeight: 23.4
                    radius: 11.7
                    color: sheet.radioOn ? sheet.cHi : sheet.cBor
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        width: 18.2; height: 18.2; radius: 9.1
                        y: 2
                        x: sheet.radioOn ? parent.width - 20.2 : 2
                        color: sheet.radioOn ? sheet.cBg : sheet.cHi
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nmHandler.enableWireless(!sheet.radioOn)
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: sheet.cBor }

            // ---- the interrupt line: red, and only when something actually failed
            Text {
                Layout.fillWidth: true
                visible: sheet.netError !== ""
                text: sheet.netError.toUpperCase()
                color: sheet.cRed
                font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.6
                elide: Text.ElideRight
            }

            // ---- networks
            ListView {
                id: netList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2.6
                model: nmProxy
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: netRow
                    // Required properties keep `model` unambiguous inside the nested
                    // Repeater below, which brings its own model into scope.
                    required property var model

                    // The proxy carries wired links and VPNs too; this sheet is Wi-Fi.
                    readonly property bool isWifi: netRow.model.Type === PlasmaNM.Enums.Wireless
                    readonly property bool active: netRow.model.ConnectionState === PlasmaNM.Enums.Activated
                    readonly property bool busy:   netRow.model.ConnectionState === PlasmaNM.Enums.Activating
                    readonly property bool secured: netRow.model.SecurityType !== PlasmaNM.Enums.NoneSecurity
                                                    && netRow.model.SecurityType !== PlasmaNM.Enums.UnknownSecurity
                    readonly property int sig: netRow.model.Signal || 0

                    width: netList.width
                    height: isWifi ? 46.8 : 0
                    visible: isWifi

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: hover.hovered || netRow.active ? sheet.cCard : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14.3
                            anchors.rightMargin: 14.3
                            spacing: 13

                            // signal: four bars, filled by strength -- greyscale is the
                            // hierarchy, so an empty bar is drawn, never hidden
                            Row {
                                spacing: 2.6
                                Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 3; radius: 1.5
                                        height: 4 + index * 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: netRow.sig >= (index + 1) * 20 ? sheet.cHi : sheet.cBor
                                        Behavior on color { ColorAnimation { duration: 220 } }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: netRow.model.Name
                                    color: sheet.cHi
                                    font.family: sheet.fUI; font.pixelSize: 13
                                    font.weight: netRow.active ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    visible: text !== ""
                                    text: netRow.active ? "CONNECTED"
                                          : netRow.busy ? "CONNECTING…"
                                          : netRow.model.Uuid ? "SAVED" : ""
                                    color: netRow.active ? sheet.cHi : sheet.cLo
                                    font.family: sheet.fMono; font.pixelSize: 9; font.letterSpacing: 0.6
                                }
                            }

                            // a padlock, drawn rather than themed, so it cannot go missing
                            Item {
                                visible: netRow.secured && !netRow.model.Uuid
                                Layout.preferredWidth: 11; Layout.preferredHeight: 14
                                Layout.alignment: Qt.AlignVCenter
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 0; width: 7; height: 7; radius: 3.5
                                    color: "transparent"
                                    border.color: sheet.cDis; border.width: 1.4
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: 11; height: 8; radius: 2
                                    color: sheet.cDis
                                }
                            }

                            Text {
                                visible: netRow.active
                                text: "×"
                                color: sheet.cLo
                                font.family: sheet.fUI; font.pixelSize: 17
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        HoverHandler { id: hover }
                        TapHandler { onTapped: sheet.activate(netRow.model) }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- password
    Item {
        anchors.fill: parent
        opacity: sheet.mode === 1 ? 1 : 0
        visible: opacity > 0
        enabled: sheet.mode === 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        onVisibleChanged: if (visible) passwordField.forceActiveFocus()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16.9
            spacing: 13

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
                        onClicked: sheet.mode = 0
                    }
                }
                Text {
                    text: "JOIN NETWORK"
                    color: sheet.cHi
                    font.family: sheet.fMono; font.pixelSize: 15; font.letterSpacing: 1.2
                    Layout.fillWidth: true
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: sheet.cBor }

            Item { Layout.preferredHeight: 6.5 }

            Text {
                text: sheet.authSsid
                color: sheet.cHi
                font.family: sheet.fUI; font.pixelSize: 26; font.weight: Font.Bold
                elide: Text.ElideRight; Layout.fillWidth: true
            }
            Text {
                text: (sheet.authSecurity || "SECURED").toUpperCase()
                color: sheet.cLo
                font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 0.8
            }

            Item { Layout.preferredHeight: 6.5 }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 49.4
                radius: height / 2
                color: sheet.cCard
                border.width: passwordField.activeFocus ? 1 : 0
                border.color: sheet.cBor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18.2
                    anchors.rightMargin: 7.8
                    spacing: 9.1

                    TextInput {
                        id: passwordField
                        Layout.fillWidth: true
                        color: sheet.cHi
                        font.family: sheet.fUI; font.pixelSize: 14
                        echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        selectByMouse: true
                        selectionColor: sheet.cHi
                        selectedTextColor: sheet.cBg
                        clip: true
                        onAccepted: sheet.join()
                        Keys.onEscapePressed: sheet.mode = 0

                        Text {
                            anchors.fill: parent
                            visible: passwordField.text === "" && !passwordField.activeFocus
                            text: "PASSWORD"
                            color: sheet.cDis
                            font.family: sheet.fMono; font.pixelSize: 11; font.letterSpacing: 0.8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        id: showPassword
                        property bool checked: false
                        Layout.preferredWidth: 33.8; Layout.preferredHeight: 33.8
                        radius: 16.9
                        color: checked ? sheet.cCard2 : "transparent"
                        Kirigami.Icon {
                            anchors.centerIn: parent; width: 15.6; height: 15.6
                            source: showPassword.checked ? "view-hidden" : "view-visible"
                            isMask: true; color: sheet.cLo
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showPassword.checked = !showPassword.checked
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9.1
                Rectangle {
                    Layout.preferredWidth: 119.6
                    Layout.preferredHeight: 44.2
                    radius: height / 2
                    color: sheet.cCard
                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: sheet.cHi
                        font.family: sheet.fMono; font.pixelSize: 11; font.letterSpacing: 0.9
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sheet.mode = 0
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44.2
                    radius: height / 2
                    // WPA-PSK is 8..63 characters; anything shorter cannot succeed,
                    // so the button stays dead rather than failing after a round trip.
                    readonly property bool ready: passwordField.text.length >= 8
                    color: ready ? sheet.cHi : sheet.cCard
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        text: "JOIN"
                        color: parent.ready ? sheet.cBg : sheet.cDis
                        font.family: sheet.fMono; font.pixelSize: 11; font.letterSpacing: 0.9
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.ready
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sheet.join()
                    }
                }
            }
        }
    }
}
