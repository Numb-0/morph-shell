import QtQuick
import qs.components
import qs.config

// Workspaces as a constellation. Each workspace in use is a star, larger
// the more windows it holds, and the stars in use are joined in order
// into a figure that redraws itself as workspaces come and go. Empty
// slots are faint specks of sky. The active star is the brightest, turns
// slowly, and on a switch shoots across as a comet with a fading tail.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 20

    readonly property real cy: height / 2

    // A fixed scatter above and below the line, so the figure reads as
    // stars rather than as beads on a string. By slot, so a workspace
    // keeps its place in the sky.
    readonly property var scatter: [0, -4, 3, -2, 4, -3, 2, -4, 3, -1]

    function starY(id: int): real {
        return cy + scatter[(id - 1) % scatter.length];
    }

    function starSize(windows: int): real {
        return windows > 0 ? 7 + Math.min(windows, 4) * 1.5 : 3;
    }

    // The figure's lines.
    Canvas {
        id: lines

        anchors.fill: parent

        readonly property color stroke: Appearance.palette.m3outline

        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()

        Connections {
            target: root.ws

            function onWindowsChanged(): void {
                lines.requestPaint();
            }
            function onCountChanged(): void {
                lines.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = stroke;
            ctx.globalAlpha = 0.55;
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 2]);

            ctx.beginPath();
            let first = true;
            for (let id = 1; id <= root.ws.count; id++) {
                if (root.ws.windowsOn(id) === 0)
                    continue;
                const x = root.ws.centerOf(id);
                const y = root.starY(id);
                if (first)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
                first = false;
            }
            ctx.stroke();
        }
    }

    // The resting stars. The one under the active star steps aside for it.
    Repeater {
        model: root.ws.count

        Sparkle {
            required property int index

            readonly property int wsId: index + 1
            readonly property int windows: root.ws.windowsOn(wsId)
            readonly property bool urgent: root.ws.urgent[wsId] ?? false

            x: root.ws.centerOf(wsId) - width / 2
            y: root.starY(wsId) - height / 2

            size: root.starSize(windows)
            pinch: windows > 0 ? 0.82 : 0
            color: urgent ? Appearance.palette.m3error : windows > 0 ? Appearance.palette.m3secondary : Appearance.palette.m3outlineVariant

            opacity: wsId === root.ws.activeId ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            // Stars that want attention twinkle.
            SequentialAnimation on scale {
                running: urgent && root.ws.running
                loops: Animation.Infinite
                alwaysRunToEnd: true

                Anim {
                    to: 1.5
                    type: Anim.SlowEffects
                }
                Anim {
                    to: 1
                    type: Anim.SlowEffects
                }
            }
        }
    }

    // The comet's tail: laid from where the active star left to where it
    // is going, fading out while the star crosses it.
    Rectangle {
        id: trail

        property real fromX: 0
        property real toX: 0

        x: Math.min(fromX, toX)
        width: Math.abs(toX - fromX)
        height: 2
        y: star.y + star.height / 2 - height / 2
        radius: 1

        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: trail.toX > trail.fromX ? "transparent" : Appearance.palette.m3primary
            }
            GradientStop {
                position: 1
                color: trail.toX > trail.fromX ? Appearance.palette.m3primary : "transparent"
            }
        }

        Anim {
            id: fadeTrail

            target: trail
            property: "opacity"
            from: 0.9
            to: 0
            type: Anim.SlowEffects
            duration: Appearance.anim.durations.defaultSpatial
        }
    }

    // A soft halo, then the active star itself.
    Sparkle {
        x: star.x + star.width / 2 - width / 2
        y: star.y + star.height / 2 - height / 2

        size: star.size * 1.5
        pinch: 0.9
        color: Appearance.palette.m3primary
        opacity: 0.18
        rotation: -star.rotation * 0.5
    }

    Sparkle {
        id: star

        readonly property real homeX: root.ws.centerOf(root.ws.activeId)

        x: homeX - width / 2
        y: root.starY(root.ws.activeId) - height / 2

        size: 16
        color: Appearance.palette.m3primary

        onHomeXChanged: {
            trail.fromX = x + width / 2;
            trail.toX = homeX;
            fadeTrail.restart();
        }

        Behavior on x {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on y {
            Anim {
                type: Anim.Emphasized
            }
        }

        RotationAnimation on rotation {
            running: root.ws.running
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 12000
        }
    }
}
