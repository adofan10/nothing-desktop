import QtQuick
import QtQuick.Layouts

/*
 * Dot-matrix clock, self-contained (no singleton import) so the same file drops into
 * both the lock screen and the SDDM theme.
 *
 * Signature moment: when a digit changes, only THAT digit's dots re-illuminate in a fast
 * left-to-right sweep — the Glyph-interface idea applied to time. Unchanged digits and
 * the colon stay perfectly still.
 */
Item {
    id: clockRoot

    // Nothing tokens, inlined as defaults
    property color colDisplay: "#ffffff"    // --text-display
    property color colSecond:  "#999999"    // --text-secondary
    property color colAccent:  "#d71921"    // --accent, INTERRUPT ONLY
    property string faceDot:   "Nothing Font (5x7)"
    property string faceMono:  "NType 82 Mono"

    property bool alert: false              // auth failed -> the one place red belongs
    property int  digitSize: 140
    property date now: new Date()

    readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
    readonly property var chars: timeText.split("")

    implicitWidth:  col.implicitWidth
    implicitHeight: col.implicitHeight

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: clockRoot.now = new Date()
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 22

        Row {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: clockRoot.chars.length

                Item {
                    id: cell
                    width:  glyph.implicitWidth
                    height: glyph.implicitHeight
                    clip: true

                    readonly property string ch: clockRoot.chars[index] || ""
                    readonly property bool isColon: ch === ":"

                    Item {
                        id: revealer
                        height: parent.height
                        width:  cell.width
                        clip: true

                        Text {
                            id: glyph
                            text: cell.ch
                            font.family: clockRoot.faceDot
                            font.pixelSize: clockRoot.digitSize
                            color: clockRoot.alert ? clockRoot.colAccent : clockRoot.colDisplay
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // linear sweep, not eased: a bank of dots powering up. Percussive.
                    NumberAnimation {
                        id: sweep
                        target: revealer; property: "width"
                        from: 0; to: cell.width
                        duration: 120
                    }

                    onChChanged: if (!isColon && cell.width > 0) sweep.restart()
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clockRoot.now, "dddd, d MMMM").toUpperCase()
            font.family: clockRoot.faceMono
            font.pixelSize: 15
            font.letterSpacing: 3
            color: clockRoot.colSecond
        }
    }
}
