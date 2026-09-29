import QtQuick
import Morph.Blobs
import qs.components
import qs.config

// Workspaces as mercury. Every workspace in use is a drop, fatter the
// more windows it holds, and the active one is a larger bead of the same
// metal: all of them share a blob group, so the bead fuses with whatever
// drop it rolls over.
//
// On a switch the bead's front end springs ahead and its back end is
// dragged after it, so the bead stretches into a thread across the row,
// swallowing the drops it passes, and gathers itself back up at the new
// slot.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 20

    readonly property real beadWidth: 16
    readonly property real beadHeight: 14

    readonly property real cy: height / 2

    // Not called group: inside a delegate that name finds the shape's
    // own group property before it finds this, and the drop is never
    // drawn.
    BlobGroup {
        id: metal

        color: Appearance.palette.m3primary

        // Tight enough that neighbouring drops at rest stay apart, loose
        // enough that the bead in transit bridges them.
        smoothing: 6

        // Squares off corners where shapes meet, which is right for a
        // panel meeting the bar and wrong for drops: the bead resting on
        // a drop would turn into a tile.
        cornerFill: false
    }

    // A faint seat for every slot, so an empty workspace still has a
    // place to be clicked. Kept out of the group: it is a mark on the
    // bar, not liquid.
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
            readonly property int windows: root.ws.windowsOn(wsId)

            // Grows a step per window up to four, so a busy workspace
            // reads as heavier without outgrowing its slot.
            property real dropSize: windows > 0 ? 6 + Math.min(windows, 4) * 1.5 : 0

            group: metal

            x: root.ws.centerOf(wsId) - width / 2
            y: root.cy - height / 2
            width: dropSize
            height: dropSize
            radius: dropSize / 2

            Behavior on dropSize {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            // Urgent: a ring that keeps breaking away from the drop, as
            // a ripple off a disturbed surface.
            Rectangle {
                id: ripple

                anchors.centerIn: parent

                readonly property bool urgent: root.ws.urgent[drop.wsId] ?? false

                width: 8
                height: 8
                radius: width / 2
                visible: urgent

                color: "transparent"
                border.width: 1.5
                border.color: Appearance.palette.m3error

                SequentialAnimation on scale {
                    running: ripple.urgent && root.ws.running
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1
                        to: 2.6
                        duration: 900
                        easing.type: Easing.OutCubic
                    }
                }

                SequentialAnimation on opacity {
                    running: ripple.urgent && root.ws.running
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1
                        to: 0
                        duration: 900
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // The bead's two ends chase the active slot, one fast and one slow,
    // and the bead spans whatever lies between them: the fast end leads
    // whichever way it goes, and the slow one is dragged after it.
    property real headX: ws.centerOf(ws.activeId)
    property real tailX: ws.centerOf(ws.activeId)

    Behavior on headX {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on tailX {
        Anim {
            type: Anim.SlowSpatial
            duration: Appearance.anim.durations.slowSpatial + 150
        }
    }

    BlobRect {
        id: bead

        readonly property real stretch: Math.abs(root.headX - root.tailX)

        group: metal

        x: Math.min(root.headX, root.tailX) - root.beadWidth / 2
        width: root.beadWidth + stretch

        // Keeps its volume as it stretches: longer is thinner, down to a
        // thread, so it reads as liquid pulled out rather than as a bar
        // growing.
        height: Math.max(4, root.beadHeight * Math.sqrt(root.beadWidth / width))
        y: root.cy - height / 2
        radius: height / 2

        deformScale: 0
    }

    // The bead's highlight, a glint that keeps the metal from reading as
    // a flat sticker. Gone while the bead is pulled thin, and back once
    // it has gathered.
    Rectangle {
        x: bead.x + 3.5
        y: bead.y + bead.height * 0.2
        width: 4.8
        height: 3
        radius: height / 2

        color: Appearance.palette.m3onPrimary
        opacity: 0.35 * Math.max(0, 1 - bead.stretch / 6)
    }
}
