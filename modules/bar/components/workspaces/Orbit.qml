import QtQuick
import qs.components
import qs.config

// Workspaces as a small solar system. Every workspace is its number; the
// active one wears a tilted ring, and its windows are moons travelling
// that ring in perspective -- larger and in front of the number on the
// near side, smaller and behind it on the far side. The ring rolls from
// one number to the next on a switch. Inactive workspaces keep their
// moons parked in a row beneath them, one per window.
Item {
    id: root

    required property Item ws

    readonly property real slotWidth: 24

    readonly property real cy: height / 2

    readonly property real ringRadiusX: 12
    readonly property real ringRadiusY: 4

    // The ring's tilt, shared by the ring and the moons so they stay on it.
    readonly property real tilt: -18

    readonly property real ringX: ring.x + ring.width / 2
    readonly property int moons: Math.min(root.ws.windowsOn(root.ws.activeId), 5)

    // One turn of the ring's moons, shared so they keep their spacing.
    property real phase: 0

    NumberAnimation on phase {
        running: root.ws.running && root.moons > 0
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 6000
    }

    // A moon's place on the ring: x and y in the widget, and depth from
    // -1 at the back to 1 at the front.
    function moonAt(i: int): var {
        const t = phase + i * Math.PI * 2 / Math.max(moons, 1);
        const ex = Math.cos(t) * ringRadiusX;
        const ey = Math.sin(t) * ringRadiusY;
        const a = tilt * Math.PI / 180;
        return {
            x: ringX + ex * Math.cos(a) - ey * Math.sin(a),
            y: cy + ex * Math.sin(a) + ey * Math.cos(a),
            depth: Math.sin(t)
        };
    }

    // The far half of the active ring's moons, behind the numbers.
    Repeater {
        model: root.moons

        Moon {
            back: true
        }
    }

    // Where the active planet sits; the ring, the body and the moons all
    // follow it, so they roll across together.
    Item {
        id: ring

        x: root.ws.centerOf(root.ws.activeId) - width / 2
        y: root.cy - height / 2
        width: root.ringRadiusX * 2
        height: root.ringRadiusY * 2

        Behavior on x {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    RingHalf {
        front: false
    }

    // The planet itself, for the active number to sit on.
    Rectangle {
        x: root.ringX - width / 2
        y: root.cy - height / 2
        width: 17
        height: 17
        radius: width / 2

        color: Appearance.palette.m3primaryContainer
    }

    Repeater {
        model: root.ws.count

        Item {
            id: planet

            required property int index

            readonly property int wsId: index + 1
            readonly property int windows: root.ws.windowsOn(wsId)
            readonly property bool active: wsId === root.ws.activeId
            readonly property bool urgent: root.ws.urgent[wsId] ?? false

            x: root.ws.centerOf(wsId) - width / 2
            width: root.slotWidth
            height: root.height

            StyledText {
                anchors.centerIn: parent

                text: planet.wsId
                font.pixelSize: planet.active ? Appearance.font.normal : Appearance.font.small
                font.bold: planet.active

                color: planet.urgent ? Appearance.palette.m3error : planet.active ? Appearance.palette.m3onPrimaryContainer : planet.windows > 0 ? Appearance.palette.m3onSurface : Appearance.palette.m3outline
            }

            // Parked moons, one per window up to four.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3

                spacing: 2
                opacity: planet.active ? 0 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Repeater {
                    model: Math.min(planet.windows, 4)

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Appearance.palette.m3secondary
                    }
                }
            }
        }
    }

    // The near half, in front of the numbers.
    RingHalf {
        front: true
    }

    Repeater {
        model: root.moons

        Moon {
            back: false
        }
    }

    // Half the ring, cut along its long axis: the far half passes behind
    // the planet and the near half in front of it.
    component RingHalf: Item {
        property bool front

        x: ring.x
        y: ring.y + (front ? ring.height / 2 : 0)
        width: ring.width
        height: ring.height / 2

        transform: Rotation {
            origin.x: ring.width / 2
            origin.y: front ? 0 : ring.height / 2
            angle: root.tilt
        }

        clip: true

        Rectangle {
            y: front ? -ring.height / 2 : 0
            width: ring.width
            height: ring.height
            radius: height / 2

            color: "transparent"
            border.width: 1.5
            border.color: Appearance.palette.m3primary
        }
    }

    component Moon: Rectangle {
        required property int index
        property bool back

        readonly property var pos: root.moonAt(index)

        // Each moon is drawn twice, once per layer, and shows in only the
        // one its side of the ring belongs to.
        visible: back === (pos.depth < 0)

        readonly property real s: 3 + (pos.depth + 1) * 1.25

        x: pos.x - s / 2
        y: pos.y - s / 2
        width: s
        height: s
        radius: s / 2

        color: Appearance.palette.m3tertiary
        opacity: 0.55 + (pos.depth + 1) * 0.225
    }
}
