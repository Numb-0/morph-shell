import QtQuick
import QtQuick.Shapes
import qs.config

// Transport icons drawn as shapes rather than glyphs, so they do not
// depend on an icon font being installed.
Item {
    id: root

    // "play" | "pause" | "previous" | "next"
    required property string kind
    property color color: Appearance.palette.text

    readonly property bool skip: kind === "previous" || kind === "next"
    readonly property bool back: kind === "previous"

    implicitWidth: 20
    implicitHeight: 20

    Row {
        anchors.centerIn: parent
        spacing: root.width * 0.16

        visible: root.kind === "pause"

        Repeater {
            model: 2

            Rectangle {
                width: root.width * 0.2
                height: root.height * 0.72
                radius: width / 2
                color: root.color
            }
        }
    }

    Shape {
        anchors.fill: parent

        visible: root.kind !== "pause"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: triangle

            readonly property real inset: root.skip ? root.width * 0.3 : root.width * 0.26
            readonly property real tip: root.width * 0.8
            readonly property real top: root.height * 0.18
            readonly property real bottom: root.height * 0.82

            fillColor: root.color
            strokeWidth: 0

            startX: root.back ? tip : inset
            startY: top

            PathLine {
                x: root.back ? triangle.inset : triangle.tip
                y: root.height / 2
            }

            PathLine {
                x: root.back ? triangle.tip : triangle.inset
                y: triangle.bottom
            }
        }
    }

    // The stop bar that turns a plain triangle into a skip icon.
    Rectangle {
        visible: root.skip

        x: root.back ? root.width * 0.14 : root.width * 0.78
        y: root.height * 0.18

        width: root.width * 0.1
        height: root.height * 0.64
        radius: width / 2
        color: root.color
    }
}
