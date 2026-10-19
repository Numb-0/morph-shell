import QtQuick
import QtQuick.Shapes
import qs.components
import qs.config

// An expressive shape for the weather, as the media panel's idle one
// is drawn: a circle with lobes cut into its edge, turning slowly.
// Which shape follows the sky -- the sunny one for sun, a puffy one
// for cloud, a flower for rain, a cookie for snow, a clover for
// storms -- and a change of sky sheds the lobes and springs back
// out as the new shape.
Shape {
    id: bloom

    property real radius: 40
    property int code: 0
    property bool turning: false
    property bool reverse: false

    readonly property var form: {
        if (code <= 1)
            return { lobes: 8, depth: 0.1 };
        if (code <= 48)
            return { lobes: 5, depth: 0.16 };
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return { lobes: 9, depth: 0.09 };
        if (code >= 95)
            return { lobes: 4, depth: 0.2 };
        return { lobes: 6, depth: 0.13 };
    }

    // The form being drawn, which trails the one asked for through
    // the shed-and-bloom.
    property var shown: form
    property real grown: 1

    onFormChanged: morph.restart()

    SequentialAnimation {
        id: morph

        Anim {
            target: bloom
            property: "grown"
            to: 0
            type: Anim.FastEffects
        }
        ScriptAction {
            script: bloom.shown = bloom.form
        }
        Anim {
            target: bloom
            property: "grown"
            to: 1
            type: Anim.FastSpatial
        }
    }

    property real spin: 0

    NumberAnimation on spin {
        running: bloom.turning
        loops: Animation.Infinite
        from: 0
        to: bloom.reverse ? -360 : 360
        duration: 24000
    }

    property color color

    readonly property real c: width / 2

    // Rebuilt only while it morphs; the turning is a transform.
    readonly property var outline: {
        const a = shown.depth * grown;
        const out = [];
        for (let i = 0; i <= 120; i++) {
            const th = i / 120 * Math.PI * 2;
            const d = radius * (1 - a * 0.35 + a * Math.cos(shown.lobes * th));
            out.push(Qt.point(c + Math.cos(th) * d, c + Math.sin(th) * d));
        }
        return out;
    }

    // Room for the lobes, which reach past the radius.
    width: radius * 2.4
    height: width

    preferredRendererType: Shape.CurveRenderer

    transform: Rotation {
        origin.x: bloom.c
        origin.y: bloom.c
        angle: bloom.spin
    }

    ShapePath {
        fillColor: bloom.color
        strokeWidth: -1

        PathPolyline {
            path: bloom.outline
        }
    }
}
