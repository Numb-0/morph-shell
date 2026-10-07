import QtQuick
import QtQuick.Shapes
import qs.components
import qs.config

// A workspace's number on its shape: the Material shape the bar's
// shapes style gives the same workspace, so the two read as one. The
// active workspace's is filled with the accent and turns slowly; the
// rest sit still and quiet.
Item {
    id: root

    required property int wsId

    property bool active: false
    property bool selected: false

    // Whether anyone can see it, so the turning stops with the overview.
    property bool running: true

    property real radius: 15

    // As the bar's shapes style has them, by workspace and wrapping past
    // the end: how many lobes ring the shape, and how deep they cut.
    readonly property var shapes: [
        { lobes: 9, depth: 0.09 }, // cookie
        { lobes: 4, depth: 0.2 }, // clover
        { lobes: 8, depth: 0.1 }, // sunny
        { lobes: 6, depth: 0.13 }, // flower
        { lobes: 5, depth: 0.16 }, // puffy
        { lobes: 12, depth: 0.06 }, // burst
        { lobes: 7, depth: 0.12 } // gem
    ]

    readonly property var shapeOf: shapes[(Math.max(1, wsId) - 1) % shapes.length]

    property real spin: 0

    width: radius * 2.4
    height: width

    scale: selected ? 1.18 : 1

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    NumberAnimation on spin {
        running: root.active && root.running
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 9000
    }

    Shape {
        id: shape

        readonly property real c: width / 2

        readonly property var outline: {
            const s = root.shapeOf;
            const r = root.radius;
            const out = [];
            for (let i = 0; i <= 120; i++) {
                const th = i / 120 * Math.PI * 2;
                const d = r * (1 - s.depth * 0.35 + s.depth * Math.cos(s.lobes * th));
                out.push(Qt.point(c + Math.cos(th) * d, c + Math.sin(th) * d));
            }
            return out;
        }

        anchors.fill: parent

        preferredRendererType: Shape.CurveRenderer

        rotation: root.spin

        ShapePath {
            fillColor: root.active ? Appearance.palette.m3primary : Appearance.palette.m3secondaryContainer
            strokeWidth: -1

            Behavior on fillColor {
                CAnim {}
            }

            PathPolyline {
                path: shape.outline
            }
        }
    }

    StyledText {
        anchors.centerIn: parent

        text: root.wsId
        font.pixelSize: Math.round(root.radius * 0.95)
        font.weight: Font.Bold
        color: root.active ? Appearance.palette.m3onPrimary : Appearance.palette.m3onSecondaryContainer
    }
}
