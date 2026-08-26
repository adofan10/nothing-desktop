import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Full-screen app drawer: Launchpad's shape -- one grid, paged sideways, a search
// field floating over a blurred desktop -- drawn in Nothing's language. Monochrome,
// dot-matrix labels, no chrome, and the only motion is a hard ease-out.
//
// The window's own translucent colour and blur come from Kicker.DashboardWindow;
// everything below is drawn on top of the live desktop.
Item {
    id: sheet
    property var drawer

    // handed back to the window so every keystroke lands in search
    property alias searchField: searchInput

    readonly property color cCard:  drawer ? drawer.cardBg   : "#111111"
    readonly property color cCard2: drawer ? drawer.cardBg2  : "#1a1a1a"
    readonly property color cBor:   drawer ? drawer.cBorder  : "#333333"
    readonly property color cHi:    drawer ? drawer.textHi   : "#ffffff"
    readonly property color cPri:   drawer ? drawer.textPri  : "#e8e8e8"
    readonly property color cLo:    drawer ? drawer.textLo   : "#999999"
    readonly property color cDis:   drawer ? drawer.textDis  : "#666666"
    readonly property string fUI:   drawer ? drawer.fontUI   : "sans"
    readonly property string fMono: drawer ? drawer.fontMono : "monospace"

    // The window is built at applet load and kept alive for the whole session, so
    // without this the grid would hold ~2 pages of 68px app icons resident from
    // login onwards. Dropping the model on close frees the delegates and their
    // pixmaps; rebuilding them on the next open costs a few milliseconds.
    readonly property bool mapped: drawer ? drawer.drawerMapped : false

    readonly property bool searching: searchInput.text.length > 0
    readonly property var appsModel: drawer ? drawer.appsModel : null
    readonly property var resultsModel:
        (drawer && drawer.runnerModel.count) ? drawer.runnerModel.modelForRow(0) : null
    readonly property var activeModel: searching ? resultsModel : appsModel

    function launch(index) {
        var m = sheet.activeModel
        if (!m || index < 0) return
        if (m.trigger) m.trigger(index, "", null)
        drawer.closeDrawer()
    }

    // Launchpad's move -- the whole surface swells in and shrinks away -- run on
    // Nothing's curve: a hard ease-out with no overshoot, and no spring anywhere.
    // The window stays mapped for the exit; AppDrawer tells the applet when the
    // last frame is done so it can finally hide.
    readonly property bool wantOpen: drawer ? drawer.drawerOpen : false
    property real reveal: 0

    onWantOpenChanged: {
        if (sheet.wantOpen) { revealOut.stop(); revealIn.restart() }
        else                { revealIn.stop();  revealOut.restart() }
    }

    NumberAnimation {
        id: revealIn
        target: sheet; property: "reveal"
        to: 1; duration: 280
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.32, 0.72, 0.0, 1.0, 1.0, 1.0]
    }
    SequentialAnimation {
        id: revealOut
        // shorter on the way out: dismissal should feel immediate
        NumberAnimation {
            target: sheet; property: "reveal"
            to: 0; duration: 190
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
        }
        ScriptAction { script: if (sheet.drawer) sheet.drawer.finishClose() }
    }

    // Called by the window every time it is shown -- the Item's own `visible`
    // never flips, because it is created once and lives inside the window.
    function resetView() {
        searchInput.text = ""
        grid.currentIndex = 0
        grid.contentX = 0
        grid.contentY = 0
        // The compositor sizes the window a frame after it is shown, so the first
        // layout can run against a zero-width grid -- that was the "messed up
        // until you type" state. Lay it out again once the size is real.
        relayout.restart()
        sheet.reveal = 0
        searchInput.forceActiveFocus()
    }
    Component.onCompleted: relayout.restart()

    Timer {
        id: relayout
        interval: 0
        repeat: false
        onTriggered: {
            grid.forceLayout()
            grid.positionViewAtBeginning()
        }
    }
    // width lands late on the first show; re-lay-out when it finally does
    onWidthChanged: if (width > 0) relayout.restart()
    onHeightChanged: if (height > 0) relayout.restart()

    // click anywhere off a tile to dismiss, the way Launchpad does
    MouseArea {
        anchors.fill: parent
        enabled: sheet.wantOpen
        onClicked: drawer.closeDrawer()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(sheet.height * 0.085)
        anchors.bottomMargin: Math.round(sheet.height * 0.045)
        anchors.leftMargin: Math.round(sheet.width * 0.06)
        anchors.rightMargin: Math.round(sheet.width * 0.06)
        spacing: Math.round(sheet.height * 0.045)

        opacity: sheet.reveal
        scale: 0.93 + 0.07 * sheet.reveal
        transformOrigin: Item.Center

        // ------------------------------------------------------------ search
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(580, sheet.width * 0.42)
            Layout.preferredHeight: 62
            radius: 31
            color: sheet.cCard
            border.width: 1
            border.color: searchInput.activeFocus ? sheet.cBor : "#00000000"
            // the search field settles a hair later than the grid
            y: (1 - sheet.reveal) * -10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 26
                anchors.rightMargin: 14
                spacing: 15

                Kirigami.Icon {
                    source: "system-search"
                    isMask: true
                    color: sheet.cLo
                    Layout.preferredWidth: 19; Layout.preferredHeight: 19
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: sheet.cHi
                    font.family: sheet.fUI
                    font.pixelSize: 18
                    selectByMouse: true
                    selectionColor: sheet.cHi
                    selectedTextColor: "#000000"
                    clip: true
                    focus: true

                    onTextChanged: {
                        if (sheet.drawer) sheet.drawer.runnerModel.query = text
                        grid.currentIndex = 0
                        grid.contentX = 0
                        grid.contentY = 0
                    }

                    Keys.onEscapePressed: {
                        if (searchInput.text.length > 0) searchInput.text = ""
                        else sheet.drawer.closeDrawer()
                    }
                    Keys.onReturnPressed: sheet.launch(grid.currentIndex)
                    Keys.onEnterPressed: sheet.launch(grid.currentIndex)
                    Keys.onDownPressed: grid.moveBy(1)
                    Keys.onUpPressed: grid.moveBy(-1)
                    Keys.onRightPressed: {
                        if (searchInput.cursorPosition === searchInput.text.length) grid.moveBy(grid.rows)
                        else searchInput.cursorPosition++
                    }
                    Keys.onLeftPressed: {
                        if (searchInput.cursorPosition === 0) grid.moveBy(-grid.rows)
                        else searchInput.cursorPosition--
                    }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_PageDown) { grid.goToPage(grid.currentPage + 1); event.accepted = true }
                        else if (event.key === Qt.Key_PageUp) { grid.goToPage(grid.currentPage - 1); event.accepted = true }
                    }

                    Text {
                        anchors.fill: parent
                        visible: searchInput.text === ""
                        text: "SEARCH APPS"
                        color: sheet.cDis
                        font.family: sheet.fMono
                        font.pixelSize: 13
                        font.letterSpacing: 1.2
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    radius: 18
                    visible: sheet.searching
                    color: clearHover.hovered ? sheet.cCard2 : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: sheet.cLo
                        font.family: sheet.fUI; font.pixelSize: 20
                    }
                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { searchInput.text = ""; searchInput.forceActiveFocus() } }
                }
            }
        }

        // ------------------------------------------------------------ grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            currentIndex: 0
            model: sheet.mapped ? sheet.activeModel : null

            // Browsing pages sideways is Launchpad's whole gesture, so the grid
            // fills columns first and scrolls horizontally. Search results read
            // left-to-right instead, because a ranked list has an order.
            flow: sheet.searching ? GridView.FlowLeftToRight : GridView.FlowTopToBottom
            flickableDirection: sheet.searching ? Flickable.VerticalFlick : Flickable.HorizontalFlick

            readonly property int columns: Math.max(3, Math.min(9, Math.floor(width / 208)))
            readonly property int rows: Math.max(2, Math.min(6, Math.floor(height / 196)))
            readonly property int perPage: columns * rows
            readonly property int pageCount:
                (sheet.searching || perPage <= 0) ? 1 : Math.max(1, Math.ceil(count / perPage))
            readonly property int currentPage:
                width > 0 ? Math.round(contentX / width) : 0

            // Cells divide the viewport exactly, so one viewport-width of content
            // is exactly one page and snapping is plain arithmetic.
            cellWidth: width > 0 ? width / columns : 208
            cellHeight: height > 0 ? height / rows : 196

            function goToPage(p) {
                if (sheet.searching) return
                var target = Math.max(0, Math.min(pageCount - 1, p))
                pageAnim.to = target * width
                pageAnim.restart()
            }
            function moveBy(delta) {
                if (count <= 0) return
                currentIndex = Math.max(0, Math.min(count - 1, currentIndex + delta))
                positionViewAtIndex(currentIndex, GridView.Contain)
            }

            NumberAnimation {
                id: pageAnim
                target: grid; property: "contentX"
                duration: 280
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.32, 0.72, 0.0, 1.0, 1.0, 1.0]
            }

            onMovementEnded: if (!sheet.searching) goToPage(Math.round(contentX / width))

            WheelHandler {
                enabled: !sheet.searching
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    var d = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x)
                    grid.goToPage(grid.currentPage + (d < 0 ? 1 : -1))
                }
            }

            delegate: Item {
                id: tile
                required property int index
                required property var model

                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool current: grid.currentIndex === tile.index

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.min(14, parent.width * 0.07)
                    radius: 26
                    color: tileHover.hovered ? sheet.cCard : "transparent"
                    border.width: tile.current && !tileHover.hovered ? 1 : 0
                    border.color: sheet.cBor
                    Behavior on color { ColorAnimation { duration: 130 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 20
                        anchors.bottomMargin: 16
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 14

                        Kirigami.Icon {
                            source: tile.model.decoration
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 68
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.model.display || ""
                            color: sheet.cPri
                            font.family: sheet.fUI
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                    }

                    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sheet.launch(tile.index) }
                }
            }

            // empty state: words, not artwork
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: sheet.searching ? "NO MATCH" : "NO APPLICATIONS"
                color: sheet.cDis
                font.family: sheet.fMono; font.pixelSize: 13; font.letterSpacing: 1.2
            }
        }

        // ------------------------------------------------------------ pager
        // Same morphing dash as the island's virtual-desktop pager: one language.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 8
            spacing: 8
            visible: !sheet.searching && grid.pageCount > 1

            Repeater {
                model: grid.pageCount
                Rectangle {
                    required property int index
                    readonly property bool active: index === grid.currentPage
                    width: active ? 26 : 7
                    height: 7
                    radius: 3.5
                    color: active ? sheet.cHi : sheet.cDis
                    Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.Bezier; easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0] } }
                    Behavior on color { ColorAnimation { duration: 190 } }
                    TapHandler { onTapped: grid.goToPage(index) }
                }
            }
        }

        // ------------------------------------------------------------ footer
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: grid.count + (sheet.searching ? " RESULTS" : " APPS") + "   ·   ESC TO CLOSE"
            color: sheet.cDis
            font.family: sheet.fMono; font.pixelSize: 10; font.letterSpacing: 1.0
        }
    }
}
