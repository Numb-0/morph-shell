import QtQuick
import Morph.Blobs
import qs.components
import qs.config

// Workspaces as liquid poured from cup to cup. Each workspace in use is a
// still drop, fuller the more windows it holds; the active one holds a
// pool of brighter liquid. On a switch the pool is poured, not carried: a
// thin stream shoots out to the new slot, the old pool drains into it as
// the new one fills and sloshes, and the stream lets go behind, a couple
// of drips trailing after it.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 20

    readonly property real poolSize: 15

    readonly property real cy: height / 2

    // Pools that show up already active fill at once while the bar first
    // lays out, and pour in once it has.
    property bool settled: false

    Component.onCompleted: Qt.callLater(() => settled = true)

    function dropSize(windows: int): real {
        return windows > 0 ? 5 + Math.min(windows, 4) * 1.25 : 0;
    }

    // None of these called group: inside a delegate that name finds the
    // shape's own group property before it finds this, and the shape is
    // never drawn. No corner fill on any: it squares off corners where
    // shapes meet, which turns drops into tiles.

    // The drops at rest. Tight, so neighbours stay apart.
    BlobGroup {
        id: still

        color: Appearance.palette.m3secondary
        smoothing: 4
        cornerFill: false
    }

    // Drops that want attention, in their own colour.
    BlobGroup {
        id: alarm

        color: Appearance.palette.m3error
        smoothing: 4
        cornerFill: false
    }

    // The liquid that moves: pools, stream and drips. Looser, so the
    // stream flares into a pool where it meets one rather than butting
    // into it.
    BlobGroup {
        id: flow

        color: Appearance.palette.m3primary
        smoothing: 8
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

            property real size: root.dropSize(root.ws.windowsOn(wsId))

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

    // A pool for every slot, empty but under the active one. Drawn over
    // the drops, so a draining pool leaves its workspace's own drop
    // standing where it was.
    Repeater {
        model: root.ws.count

        BlobRect {
            id: pool

            required property int index

            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.ws.activeId

            property real fill: 0

            // 0 to 1 after the pour lands: the pool jiggles as a spring
            // let go, wide then tall then wide, losing a little each time.
            property real wobble: 1
            readonly property real jiggle: wobble < 1 ? 0.2 * Math.exp(-4 * wobble) * Math.sin(wobble * 6 * Math.PI) : 0

            readonly property real size: root.poolSize * Math.max(0, fill)

            group: fill > 0.02 ? flow : null

            x: root.ws.centerOf(wsId) - width / 2
            y: root.cy - height / 2
            width: size * (1 + jiggle)
            height: size * (1 - jiggle)
            radius: Math.min(width, height) / 2

            deformScale: 0

            function pourIn(): void {
                drain.stop();
                pour.restart();
            }

            onActiveChanged: {
                if (active) {
                    pourIn();
                } else {
                    pour.stop();
                    drain.restart();
                }
            }

            Component.onCompleted: {
                if (!active)
                    return;
                if (root.settled)
                    pourIn();
                else
                    fill = 1;
            }

            // Waits for the stream to reach it, then fills past the brim
            // and settles, sloshing.
            SequentialAnimation {
                id: pour

                PauseAnimation {
                    duration: 140
                }
                ParallelAnimation {
                    Anim {
                        target: pool
                        property: "fill"
                        to: 1
                        type: Anim.SlowSpatial
                    }
                    NumberAnimation {
                        target: pool
                        property: "wobble"
                        from: 0
                        to: 1
                        duration: 800
                    }
                }
            }

            NumberAnimation {
                id: drain

                target: pool
                property: "fill"
                to: 0
                duration: 380
                easing.type: Easing.InOutCubic
            }
        }
    }

    // The stream's two ends. The head shoots out to the new slot; the
    // tail clings to the old one, then lets go and catches up, easing in
    // so the stream draws back into the pool instead of snapping off.
    property real headX: ws.centerOf(ws.activeId)
    property real tailX: ws.centerOf(ws.activeId)

    Behavior on headX {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Behavior on tailX {
        NumberAnimation {
            duration: 480
            easing.type: Easing.InOutCubic
        }
    }

    BlobRect {
        readonly property real stretch: Math.abs(root.headX - root.tailX)

        group: stretch > 1 ? flow : null

        x: Math.min(root.headX, root.tailX)
        width: stretch

        // Thins as it draws out, so a long pour reads as a jet rather
        // than as a bar.
        height: Math.max(2, 3.5 - stretch / 40)
        y: root.cy - height / 2
        radius: height / 2

        deformScale: 0
    }

    // Drips left behind by the tail, falling further back the smaller
    // they are, and shrinking into the pool as they reach it: one left
    // inside would still bulge its edge, and wobble it as it settles.
    Repeater {
        model: [
            {
                size: 4.5,
                duration: 560
            },
            {
                size: 3,
                duration: 660
            }
        ]

        BlobRect {
            id: drip

            required property var modelData

            readonly property real home: root.ws.centerOf(root.ws.activeId)
            property real cx: home

            // Full size until it is inside the pool, gone at its centre.
            readonly property real size: modelData.size * Math.min(1, Math.abs(cx - home) / (root.poolSize / 2))

            // Lets go slowly and slows again on arrival, rather than
            // stopping dead inside the pool.
            Behavior on cx {
                NumberAnimation {
                    duration: drip.modelData.duration
                    easing.type: Easing.InOutCubic
                }
            }

            group: size > 0.5 ? flow : null

            x: cx - width / 2
            y: root.cy - height / 2
            width: size
            height: size
            radius: width / 2

            deformScale: 0
        }
    }
}
