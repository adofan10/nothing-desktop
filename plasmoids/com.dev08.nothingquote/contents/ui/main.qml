import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"
import "quotes.js" as Quotes

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    NothingColors {
        id: nColors
        themeMode: plasmoid.configuration.themeMode
        useSystemAccent: plasmoid.configuration.useSystemAccent
    }

    FontLoader {
        id: serifLightFont
        source: Qt.resolvedUrl("../fonts/serif-light.otf")
    }
    FontLoader {
        id: serifFont
        source: Qt.resolvedUrl("../fonts/serif.otf")
    }

    // Day number in *local* time. Dividing Date.now() by 86400000 would roll the
    // quote over at UTC midnight, which is 05:30 here.
    function localDayNumber(date) {
        return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000)
    }

    property int dayNumber: localDayNumber(new Date())
    // Bumped by clicking; a new day clears it and the day's own quote returns.
    property int shuffleOffset: 0

    readonly property int quoteIndex: {
        const n = Quotes.quotes.length
        return (((dayNumber + shuffleOffset) % n) + n) % n
    }
    readonly property string quoteText: Quotes.quotes[quoteIndex].t
    readonly property string quoteAuthor: Quotes.quotes[quoteIndex].a

    function refreshDay() {
        const today = localDayNumber(new Date())
        if (today !== root.dayNumber) {
            root.dayNumber = today
            root.shuffleOffset = 0
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refreshDay()
    }

    Plasmoid.title: i18n("Quote of the Day")
    toolTipMainText: root.quoteText
    toolTipSubText: root.quoteAuthor

    compactRepresentation: Item {
        id: compactItem

        Layout.minimumWidth: compactText.implicitWidth + 8
        Layout.minimumHeight: compactText.implicitHeight + 8

        Text {
            id: compactText
            anchors.centerIn: parent
            text: "“"
            font.family: serifFont.name
            font.pixelSize: Math.max(12, Math.min(compactItem.width, compactItem.height) * 0.9)
            color: nColors.textPrimary
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        id: full

        Layout.preferredWidth: 420
        Layout.preferredHeight: 210
        Layout.minimumWidth: 220
        Layout.minimumHeight: 110

        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.margins: 10
            color: nColors.background
            // Stadium, like the clock pill this replaced -- the widget grid row
            // keeps its silhouette, only the contents change.
            radius: height / 2
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                // The rounded ends eat the corners, so text has to stay clear of
                // them. Capped against width too, for narrow resizes.
                anchors.leftMargin: Math.min(pill.height * 0.36, pill.width * 0.2)
                anchors.rightMargin: anchors.leftMargin
                anchors.topMargin: pill.height * 0.17
                anchors.bottomMargin: pill.height * 0.14
                spacing: Math.round(pill.height * 0.045)

                Text {
                    id: quoteLabel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.quoteText
                    color: nColors.textPrimary
                    font.family: serifLightFont.name
                    font.pixelSize: Math.round(pill.height * 0.16)
                    minimumPixelSize: Math.max(7, Math.round(pill.height * 0.075))
                    fontSizeMode: Text.Fit
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: authorLabel
                    Layout.fillWidth: true
                    text: root.quoteAuthor.toUpperCase()
                    color: nColors.accent
                    font.family: serifLightFont.name
                    font.pixelSize: Math.max(8, Math.round(pill.height * 0.082))
                    font.letterSpacing: 2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shuffleOffset += 1
            }
        }
    }
}
