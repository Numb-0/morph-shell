import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.config

// One workspace in the overview: the screen in miniature, with nothing
// behind its windows, so only they show. The free workspace past the
// ones in use is only a dashed outline with a plus, as somewhere to go
// rather than a screen.
ClippingRectangle {
    id: root

    required property int wsId

    // The workspace a dragged window would drop into.
    property bool target: false

    // The free one, to go to or to drop a window into.
    property bool fresh: false

    // 0 to 1 as it pops in, overshooting a little on the way.
    property real appear: 1

    readonly property bool hovered: area.containsMouse

    signal entered
    signal picked

    // As round as the windows in it, so it keeps the screen's shape.
    radius: Appearance.rounding.small
    color: "transparent"

    border.width: !fresh && target ? 2 : 0
    border.color: Appearance.palette.m3tertiary

    opacity: Math.min(1, appear)
    scale: 0.82 + 0.18 * appear

    Behavior on x {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on y {
        Anim {
            type: Anim.FastSpatial
        }
    }

    // Lifts the cell a dragged window is over, or the pointer.
    Rectangle {
        anchors.fill: parent

        radius: root.radius
        color: root.fresh && !root.target ? Appearance.palette.m3primary : Appearance.palette.m3tertiary
        opacity: root.target ? 0.2 : root.hovered ? 0.08 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    // The free workspace's outline, dashed, and solid while a window is
    // over it.
    Shape {
        anchors.fill: parent

        visible: root.fresh
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.target ? Appearance.palette.m3tertiary : root.hovered ? Appearance.palette.m3primary : Appearance.palette.m3outline
            strokeWidth: 2
            strokeStyle: root.target ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: [4, 3]
            fillColor: "transparent"

            Behavior on strokeColor {
                CAnim {}
            }

            PathRectangle {
                x: 1
                y: 1
                width: root.width - 2
                height: root.height - 2
                radius: root.radius - 1
            }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent

        visible: root.fresh
        icon: "add"
        size: Math.round(root.height * 0.32)
        color: root.target ? Appearance.palette.m3tertiary : root.hovered ? Appearance.palette.m3primary : Appearance.palette.m3onSurfaceVariant
        opacity: root.hovered || root.target ? 0.9 : 0.5

        // A quarter turn as the pointer comes over it.
        rotation: root.hovered || root.target ? 90 : 0
        scale: root.hovered || root.target ? 1.15 : 1

        Behavior on rotation {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.entered()
        onClicked: root.picked()
    }
}
