import QtQuick
import QtQuick.Shapes
import qs.components
import qs.config

// Workspaces as Material 3 Expressive shapes. Each workspace in use is a
// still drop, fuller the more windows it holds; the active one is a shape
// of its own -- a cookie on the first, a clover on the second -- turning
// slowly. On a switch it sheds its lobes down to a plain circle, rolls a
// quarter turn the way it travels, and blooms into the shape of the
// workspace it lands on.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 20

    readonly property real shapeRadius: 8.5

    readonly property real cy: height / 2

    // Each workspace's shape, by slot and wrapping past the end: how many
    // lobes ring it, and how deep they cut, as a share of the radius.
    readonly property var shapes: [
        { lobes: 9, depth: 0.09 }, // cookie
        { lobes: 4, depth: 0.2 }, // clover
        { lobes: 8, depth: 0.1 }, // sunny
        { lobes: 6, depth: 0.13 }, // flower
        { lobes: 5, depth: 0.16 }, // puffy
        { lobes: 12, depth: 0.06 }, // burst
        { lobes: 7, depth: 0.12 } // gem
    ]

    function shapeOf(id: int): var {
        return shapes[(id - 1) % shapes.length];
    }

    function stillSize(windows: int): real {
        return windows > 0 ? 5 + Math.min(windows, 4) * 1.25 : 0;
    }

    // The workspace the shape last set off for. Kept here rather than
    // read back off the shape, which may already stand at the new slot by
    // the time a switch is heard.
    property int lastId: 0

    // Whose shape is drawn. It changes only while the shape is a plain
    // circle, so the swap never shows.
    property int shapeId: 1

    // Where the shape set off from and is headed: a switch caught
    // mid-flight sets off again from wherever the shape is.
    property real fromX: 0
    property real toX: 0

    // 0 to 1 across the flight, already eased.
    property real travel: 1

    // 0 is a plain circle, 1 the shape in full.
    property real bloom: 1

    // Quarter turns rolled so far, the idle spin aside.
    property real turn: 0

    property real spin: 0

    readonly property real shapeX: fromX + (toX - fromX) * travel

    // Drawn out along the bar in flight; the height gives back what the
    // width takes.
    readonly property real stretch: 1 + 0.2 * Math.max(0, Math.sin(Math.PI * travel))

    // A workspace already active as the bar comes up is simply there.
    Component.onCompleted: {
        lastId = ws.activeId;
        shapeId = lastId;
        toX = ws.centerOf(lastId);
        fromX = toX;
    }

    function shift(): void {
        fromX = shapeX;
        toX = ws.centerOf(ws.activeId);
        lastId = ws.activeId;
        turn += toX > fromX ? 1 : -1;
        flight.restart();
        morph.restart();
    }

    Connections {
        target: root.ws

        function onActiveIdChanged(): void {
            if (root.lastId > 0 && root.ws.activeId !== root.lastId)
                root.shift();
        }
    }

    Behavior on turn {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Anim {
        id: flight

        target: root
        property: "travel"
        from: 0
        to: 1
        type: Anim.DefaultSpatial
    }

    // Shed the lobes, take on the new workspace's while round, and spring
    // them back out.
    SequentialAnimation {
        id: morph

        Anim {
            target: root
            property: "bloom"
            to: 0
            type: Anim.FastEffects
        }
        ScriptAction {
            script: root.shapeId = root.lastId
        }
        Anim {
            target: root
            property: "bloom"
            to: 1
            type: Anim.FastSpatial
        }
    }

    NumberAnimation on spin {
        running: root.ws.running
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 9000
    }

    // The resting drops, and a faint seat for every empty slot so it
    // still has a place to be clicked.
    Repeater {
        model: root.ws.count

        Rectangle {
            id: drop

            required property int index

            readonly property int wsId: index + 1
            readonly property int windows: root.ws.windowsOn(wsId)
            readonly property bool urgent: root.ws.urgent[wsId] ?? false

            property real size: windows > 0 ? root.stillSize(windows) : 4

            // Swells and settles while urgent.
            property real boil: 1

            Behavior on size {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            x: root.ws.centerOf(wsId) - width / 2
            y: root.cy - height / 2
            width: size * boil
            height: size * boil
            radius: width / 2

            color: urgent ? Appearance.palette.m3error : windows > 0 ? Appearance.palette.m3secondary : Appearance.palette.m3outlineVariant

            SequentialAnimation on boil {
                running: drop.urgent && root.ws.running
                loops: Animation.Infinite
                alwaysRunToEnd: true

                Anim {
                    to: 1.35
                    type: Anim.SlowEffects
                }
                Anim {
                    to: 1
                    type: Anim.SlowEffects
                }
            }
        }
    }

    // The active shape. The outline is rebuilt only while it morphs; the
    // spin and the stretch are transforms on the finished path.
    Shape {
        id: shape

        readonly property real c: width / 2

        readonly property var outline: {
            const s = root.shapeOf(root.shapeId);
            const a = s.depth * root.bloom;
            const r = root.shapeRadius;
            const out = [];
            for (let i = 0; i <= 120; i++) {
                const th = i / 120 * Math.PI * 2;
                const d = r * (1 - a * 0.35 + a * Math.cos(s.lobes * th));
                out.push(Qt.point(c + Math.cos(th) * d, c + Math.sin(th) * d));
            }
            return out;
        }

        // Room for the lobes, which reach past the radius at full bloom.
        width: root.shapeRadius * 2.4
        height: width
        x: root.shapeX - c
        y: root.cy - c

        preferredRendererType: Shape.CurveRenderer

        transform: [
            Rotation {
                origin.x: shape.c
                origin.y: shape.c
                angle: root.spin + root.turn * 90
            },
            Scale {
                origin.x: shape.c
                origin.y: shape.c
                xScale: root.stretch
                yScale: 1 / root.stretch
            }
        ]

        ShapePath {
            fillColor: Appearance.palette.m3primary
            strokeWidth: -1

            PathPolyline {
                path: shape.outline
            }
        }
    }
}
