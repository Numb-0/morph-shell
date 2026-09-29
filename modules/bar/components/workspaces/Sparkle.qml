import QtQuick
import QtQuick.Shapes
import qs.components

// A four-pointed star, its sides curving in towards the middle -- the
// sparkle, rather than a polygon star.
Shape {
    id: root

    property real size: 10
    property color color

    // How far the sides bow in: 0 is a diamond, 1 pinches them to lines.
    property real pinch: 0.82

    readonly property real c: size / 2
    readonly property real k: c * (1 - pinch)

    width: size
    height: size

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeWidth: -1

        startX: root.c
        startY: 0

        PathQuad {
            x: root.size
            y: root.c
            controlX: root.c + root.k
            controlY: root.c - root.k
        }
        PathQuad {
            x: root.c
            y: root.size
            controlX: root.c + root.k
            controlY: root.c + root.k
        }
        PathQuad {
            x: 0
            y: root.c
            controlX: root.c - root.k
            controlY: root.c + root.k
        }
        PathQuad {
            x: root.c
            y: 0
            controlX: root.c - root.k
            controlY: root.c - root.k
        }
    }

    Behavior on size {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on color {
        CAnim {}
    }
}
