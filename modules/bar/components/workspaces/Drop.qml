import QtQuick
import Morph.Blobs
import qs.components
import qs.config

// Workspaces as a drop that leaps from slot to slot, after the bouncing
// ball of liquid tab bars. Each workspace in use is a still drop, fuller
// the more windows it holds; the active one is a larger drop of brighter
// liquid. On a switch it crouches, springs off in an arc -- tearing away
// from a foot of itself left behind, which thins to a thread and snaps --
// and lands flat in a splash that runs out and gathers back into it,
// jiggling until it settles.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 20

    readonly property real dropSize: 14

    readonly property real cy: height / 2

    function stillSize(windows: int): real {
        return windows > 0 ? 5 + Math.min(windows, 4) * 1.25 : 0;
    }

    readonly property real targetX: ws.centerOf(ws.activeId)

    // The workspace the drop last set off for. Kept here rather than read
    // back off the drop, which by the time a switch is heard may already
    // stand at the new slot.
    property int lastId: 0

    // Where the leap set off from and is headed, and how high the drop
    // already was: a switch caught mid-air leaps on from wherever the
    // drop is.
    property real fromX: 0
    property real toX: 0
    property real fromLift: 0
    property real launchX: 0

    // A workspace already active as the bar comes up is simply there.
    Component.onCompleted: lastId = ws.activeId

    // 0 to 1 across the flight, linear; the motion eases off it.
    property real t: 1

    // 0 to 1 as the drop crouches to jump, and back as it lets go.
    property real crouch: 0

    // 0 to 1 after landing: the drop jiggles as a spring let go, flat
    // then tall then flat, losing a little each time.
    property real wobble: 1

    // 0 to 1 and back as the splash runs out under the landing drop.
    property real splash: 0

    // 1 to 0 as the foot left at take-off thins away.
    property real foot: 0

    readonly property real flying: t < 1 ? 1 : 0
    readonly property real ease: t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2

    // Higher for a longer leap, but always inside the bar.
    readonly property real arc: Math.min(7, 3 + Math.abs(toX - fromX) / slotWidth * 1.5)

    readonly property real dropX: t < 1 ? fromX + (toX - fromX) * ease : targetX
    readonly property real lift: fromLift * (1 - t) + arc * 4 * t * (1 - t)

    readonly property real jiggle: wobble < 1 ? 0.25 * Math.exp(-4 * wobble) * Math.sin(wobble * 6 * Math.PI) : 0

    // Wide when crouched or landing, drawn out a touch in the air; the
    // height gives back what the width takes, as liquid keeps its volume.
    readonly property real stretchX: (1 + jiggle) * (1 + 0.25 * crouch) * (1 + 0.18 * Math.sin(Math.PI * t))

    function leap(): void {
        const midAir = flight.running || takeoff.running;
        fromX = midAir ? dropX : ws.centerOf(lastId);
        fromLift = midAir ? lift : 0;
        toX = targetX;
        lastId = ws.activeId;
        takeoff.stop();
        flight.stop();
        landing.stop();
        wobble = 1;
        splash = 0;
        if (midAir) {
            crouch = 0;
            t = 0;
            flight.start();
        } else {
            launchX = fromX;
            t = 0;
            takeoff.start();
        }
    }

    Connections {
        target: root.ws

        function onActiveIdChanged(): void {
            if (root.lastId > 0 && root.ws.activeId !== root.lastId)
                root.leap();
        }
    }

    // Crouch, then spring off: the foot starts to thin the moment the
    // drop leaves it.
    SequentialAnimation {
        id: takeoff

        NumberAnimation {
            target: root
            property: "crouch"
            to: 1
            duration: 90
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: {
                root.foot = 1;
                flight.start();
            }
        }
    }

    ParallelAnimation {
        id: flight

        NumberAnimation {
            target: root
            property: "t"
            from: 0
            to: 1
            duration: 380
        }
        NumberAnimation {
            target: root
            property: "crouch"
            to: 0
            duration: 140
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: root
            property: "foot"
            to: 0
            duration: 280
            easing.type: Easing.InCubic
        }

        onFinished: landing.start()
    }

    ParallelAnimation {
        id: landing

        NumberAnimation {
            target: root
            property: "wobble"
            from: 0
            to: 1
            duration: 750
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "splash"
                from: 0
                to: 1
                duration: 110
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "splash"
                to: 0
                duration: 320
                easing.type: Easing.InOutCubic
            }
        }
    }

    // None of these called group: inside a delegate that name finds the
    // shape's own group property before it finds this, and the shape is
    // never drawn. No corner fill on any: it squares off corners where
    // shapes meet, which turns drops into tiles.

    BlobGroup {
        id: still

        color: Appearance.palette.m3secondary
        smoothing: 4
        cornerFill: false
    }

    BlobGroup {
        id: alarm

        color: Appearance.palette.m3error
        smoothing: 4
        cornerFill: false
    }

    // The leaping drop, its foot and its splash. Loose enough that the
    // drop pulls a thread out of the foot before tearing free.
    BlobGroup {
        id: leaper

        color: Appearance.palette.m3primary
        smoothing: 7
        cornerFill: false
    }

    // A faint seat for every empty slot, so it still has a place to be
    // clicked. Kept out of the groups: it is a mark on the bar, not
    // liquid.
    Repeater {
        model: root.ws.count

        Rectangle {
            required property int index

            readonly property int wsId: index + 1

            x: root.ws.centerOf(wsId) - width / 2
            y: root.cy - height / 2
            width: 4
            height: 4
            radius: 2

            color: Appearance.palette.m3outlineVariant
            opacity: root.ws.windowsOn(wsId) > 0 ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }

    Repeater {
        model: root.ws.count

        BlobRect {
            id: drop

            required property int index

            readonly property int wsId: index + 1
            readonly property bool urgent: root.ws.urgent[wsId] ?? false

            property real size: root.stillSize(root.ws.windowsOn(wsId))

            // Swells and settles while urgent, as a drop coming to the
            // boil.
            property real boil: 1

            Behavior on size {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            group: size > 0.5 ? (urgent ? alarm : still) : null

            x: root.ws.centerOf(wsId) - width / 2
            y: root.cy - height / 2
            width: size * boil
            height: size * boil
            radius: width / 2

            deformScale: 0

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

    // What stays behind at take-off, sitting low where the drop stood,
    // and thinning away as the drop pulls clear of it.
    BlobRect {
        readonly property real size: root.dropSize * 0.6 * root.foot

        group: size > 0.5 ? leaper : null

        x: root.launchX - width / 2
        y: root.cy + root.dropSize / 2 - height
        width: size * 1.3
        height: size
        radius: height / 2

        deformScale: 0
    }

    // The splash: a flat lens running out along the bar under the
    // landing drop and gathering back into it.
    BlobRect {
        group: root.splash > 0.02 ? leaper : null

        x: root.toX - width / 2
        y: root.cy + root.dropSize / 2 - height
        width: 4 + 18 * root.splash
        height: 2 + 3 * root.splash
        radius: height / 2

        deformScale: 0
    }

    // The drop itself. It keeps its bottom on the bar as it flattens,
    // rather than shrinking towards its middle.
    BlobRect {
        group: leaper

        width: root.dropSize * root.stretchX
        height: root.dropSize / root.stretchX
        x: root.dropX - width / 2
        y: root.cy + root.dropSize / 2 - height - root.lift
        radius: Math.min(width, height) / 2

        deformScale: 0
    }
}
