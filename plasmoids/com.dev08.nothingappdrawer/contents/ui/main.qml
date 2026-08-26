import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker

// Nothing-OS app drawer.
//
// Declaring X-Plasma-Provides = org.kde.plasma.launchermenu is what makes the
// Meta key open this: plasmashell's existing "activate application launcher"
// shortcut looks for whichever applet claims that, and there was none in this
// layout until now.
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ------------------------------------------------------------ palette
    // Same Nothing tokens as the dynamic island -- the two are one system.
    readonly property color drawerBg: "#000000"
    readonly property color cardBg:   "#111111"
    readonly property color cardBg2:  "#1a1a1a"
    readonly property color cBorder:  "#333333"
    readonly property color textHi:   "#ffffff"
    readonly property color textPri:  "#e8e8e8"
    readonly property color textLo:   "#999999"
    readonly property color textDis:  "#666666"
    readonly property string fontUI:   "NType 82"
    readonly property string fontMono: "NType 82 Mono"

    // ------------------------------------------------------------ models
    readonly property Kicker.RootModel rootModel: Kicker.RootModel {
        appletInterface: root
        flat: true                 // one long list, no category tree
        sorted: true               // A-Z, which is the whole point of a drawer
        showSeparators: false
        showTopLevelItems: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
    }

    // RootModel is a model *of models*; the flat "everything" one identifies
    // itself by description rather than by a fixed row, which moves about.
    readonly property var appsModel: {
        var n = rootModel.count
        for (var i = 0; i < n; ++i) {
            var m = rootModel.modelForRow(i)
            if (m && m.description === "KICKER_ALL_MODEL") return m
        }
        return n > 0 ? rootModel.modelForRow(0) : null
    }

    readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        appletInterface: root
        mergeResults: true         // one ranked list, not one section per runner
        favoritesModel: root.rootModel.favoritesModel
        query: ""
    }

    // ------------------------------------------------------------ state
    // Two flags, because closing is animated: `drawerOpen` is the intent, and
    // `drawerMapped` keeps the window on screen until the exit animation has
    // finished. Collapsing them into one would cut the close animation off at
    // its first frame.
    property bool drawerOpen: false
    property bool drawerMapped: false
    property Item anchorItem: null

    function openDrawer(anchor) {
        if (anchor) root.anchorItem = anchor
        root.drawerMapped = true      // map first, so the content can fade in
        root.drawerOpen = true
    }
    function closeDrawer() { root.drawerOpen = false }   // AppDrawer calls finishClose()
    function finishClose()  { root.drawerMapped = false }
    function toggleDrawer(anchor) {
        if (root.drawerOpen) root.closeDrawer()
        else root.openDrawer(anchor)
    }

    // Assigned, not bound: DashboardWindow hides itself in C++ when it loses
    // focus, and that would tear down a `visible:` binding for good.
    onDrawerMappedChanged: drawerWindow.visible = root.drawerMapped

    // ------------------------------------------------------------ representations
    // Same shape as the dynamic island: the real surface is our own frameless
    // dialog, but a panel applet still needs *a* full representation to exist or
    // Plasma throws the compact one away. The Meta shortcut expands that stub, so
    // collapse it again straight away and open the drawer instead.
    compactRepresentation: StartButton { drawer: root }
    fullRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }

    onExpandedChanged: {
        if (root.expanded) {
            root.expanded = false
            root.toggleDrawer()
        }
    }

    // Full-screen, translucent, blurred -- Launchpad's footprint, Nothing's face.
    // Kicker's DashboardWindow is the primitive KDE's own Application Dashboard
    // uses: it takes the whole screen of visualParent, enables blur-behind, and
    // funnels every keystroke into keyEventProxy so typing always reaches search.
    Kicker.DashboardWindow {
        id: drawerWindow
        visualParent: root.anchorItem
        keyEventProxy: drawerContent.searchField

        // The dim rides the same curve as the content, so the desktop darkens
        // and clears with the grid instead of snapping to black under it.
        backgroundColor: Qt.rgba(0, 0, 0, 0.76 * drawerContent.reveal)

        onVisibleChanged: {
            if (visible) {
                drawerContent.resetView()
            } else {
                root.drawerOpen = false
                root.drawerMapped = false
            }
        }
        onKeyEscapePressed: root.closeDrawer()

        mainItem: AppDrawer {
            id: drawerContent
            drawer: root
            width:  drawerWindow.width
            height: drawerWindow.height
        }
    }

    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    toolTipMainText: "Apps"
    toolTipSubText: "All applications"
}
