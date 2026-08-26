import QtQuick
import QtQuick.Layouts

// The start button: Nothing's dot-matrix language, not a logo.
// Nine dots read as "everything", and inverting them is the whole open state --
// no spin, no bounce, which Nothing's own motion rules rule out anyway.
Item {
    id: btn
    property var drawer

    readonly property int side: 52

    implicitWidth: side
    implicitHeight: side
    Layout.preferredWidth: side
    Layout.minimumWidth: side
    Layout.maximumWidth: side
    Layout.fillHeight: true

    readonly property bool open: drawer ? drawer.drawerOpen : false
    readonly property color cOn:  drawer ? drawer.textHi  : "#ffffff"
    readonly property color cOff: drawer ? drawer.textPri : "#e8e8e8"

    Component.onCompleted: if (btn.drawer) btn.drawer.anchorItem = btn

    Rectangle {
        id: face
        anchors.centerIn: parent
        width: 44; height: 44
        radius: 15
        color: btn.open ? btn.cOn
             : hover.hovered ? (btn.drawer ? btn.drawer.cardBg2 : "#1a1a1a")
             : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: 5.5
            Repeater {
                model: 9
                Rectangle {
                    width: 4.5; height: 4.5; radius: 2.25
                    color: btn.open ? (btn.drawer ? btn.drawer.drawerBg : "#000000")
                                    : (hover.hovered ? btn.cOn : btn.cOff)
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: btn.drawer.toggleDrawer(btn)
    }
}
