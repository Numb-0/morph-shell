import QtQuick
import qs.components
import qs.config

// One of the session menu's buttons: a large tonal container over its
// label. It is a rounded square at rest and morphs to a circle when
// chosen, as M3 Expressive's shape-morphing buttons do, filling with the
// primary colour -- or, for an action that ends the session, the error
// container, and the full error colour once armed.
//
// Arming plays the lock's wrong try on the button: it shakes like a head
// and a ring leaves its edge. Taking it plays the right one: the ring
// goes out in the success colour, the button swells, and the others draw
// in to it and melt away into it, as it fills with the success colour.
Item {
    id: root

    required property SessionMenu menu
    required property var action
    required property int position

    // How far along the row the chosen button sits from this one.
    property real target: 0

    readonly property bool selected: menu.selected === position
    readonly property bool armed: menu.armed === action.name
    readonly property bool hovered: area.containsMouse

    readonly property int size: 112

    // Runs 0 to 1 over a shake: a spring let go, swinging and dying away
    // to land back on zero.
    property real shakeT: 1
    readonly property real shakeOffset: 12 * Math.exp(-5 * shakeT) * Math.sin(shakeT * 7 * Math.PI)

    // 0 to 1 as an action is taken: the chosen button swells, the rest
    // run in to it, shrinking as they go, the outer ones a beat after.
    property real gather: 0
    property real swell: 0

    readonly property bool taken: menu.committing && selected

    readonly property color containerColor: {
        if (taken)
            return Appearance.palette.m3success;
        if (armed)
            return Appearance.palette.m3error;
        if (selected)
            return action.confirm ? Appearance.palette.m3errorContainer : Appearance.palette.m3primary;
        return Appearance.palette.m3surfaceContainerHigh;
    }

    readonly property color contentColor: {
        if (taken)
            return Appearance.palette.m3onSuccess;
        if (armed)
            return Appearance.palette.m3onError;
        if (selected)
            return action.confirm ? Appearance.palette.m3onErrorContainer : Appearance.palette.m3onPrimary;
        return Appearance.palette.m3onSurface;
    }

    implicitWidth: size
    implicitHeight: size + Appearance.spacing.medium + label.implicitHeight

    transform: Translate {
        x: root.shakeOffset + root.target * root.gather
    }

    z: selected ? 1 : 0

    Connections {
        target: root.menu

        function onArmedAction(index: int): void {
            if (index !== root.position)
                return;
            shake.restart();
            ring.burst(Appearance.palette.m3error);
        }

        function onCommitted(index: int): void {
            if (index === root.position) {
                ring.burst(Appearance.palette.m3success);
                swellAnim.restart();
            } else {
                gatherAnim.restart();
            }
        }
    }

    NumberAnimation {
        id: shake

        target: root
        property: "shakeT"
        from: 0
        to: 1
        duration: 650
    }

    SequentialAnimation {
        id: gatherAnim

        PauseAnimation {
            duration: Math.abs(root.target) / (root.size + Appearance.spacing.extraLarge) * 40
        }
        NumberAnimation {
            target: root
            property: "gather"
            from: 0
            to: 1
            duration: 320
            easing.type: Easing.InOutCubic
        }
    }

    Anim {
        id: swellAnim

        target: root
        property: "swell"
        from: 0
        to: 1
        type: Anim.SlowSpatial
    }

    // A ring that leaves the container's edge and spreads out as it
    // fades: in the error colour on arming, in success on taking it.
    Rectangle {
        id: ring

        x: container.x
        y: container.y
        width: container.width
        height: container.height
        radius: container.radius
        rotation: container.rotation
        color: "transparent"
        border.width: 2

        opacity: 0

        function burst(c: color): void {
            border.color = c;
            ringBurst.restart();
        }

        ParallelAnimation {
            id: ringBurst

            NumberAnimation {
                target: ring
                property: "scale"
                from: 1
                to: 1.35
                duration: 600
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: ring
                property: "opacity"
                from: 0.7
                to: 0
                duration: 600
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        id: container

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: root.size
        height: root.size

        radius: root.selected || root.armed ? height / 2 : Appearance.rounding.extraLarge
        color: root.containerColor

        // Leans with the shake, as the lock's field does.
        rotation: root.shakeOffset * 0.4

        scale: (root.selected ? 1.06 : 1) * (1 + 0.12 * root.swell) * (1 - 0.6 * root.gather)
        opacity: 1 - Math.max(0, root.gather - 0.5) / 0.5

        Behavior on radius {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on color {
            CAnim {
                duration: Appearance.anim.durations.fastEffects
            }
        }

        // Only the choice eases; the swell and gather are animated
        // already and would only be slowed down by it.
        Behavior on scale {
            enabled: !root.menu.committing

            Anim {
                type: Anim.FastSpatial
            }
        }

        // The M3 state layer: a wash of the content colour under the
        // pointer, a stronger one while pressed.
        Rectangle {
            anchors.fill: parent

            radius: parent.radius
            color: root.contentColor
            opacity: area.pressed ? 0.16 : root.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent

            icon: root.action.icon
            size: 40

            // Kept out of the container's growth on being chosen, which
            // would stretch the native glyph as a bitmap and blur it.
            // Qt's own rendering would scale cleanly, but draws the
            // filled glyphs' overlapping contours with seams. The swell
            // and gather still carry it, being over in a moment.
            scale: (1 + 0.12 * root.swell) * (1 - 0.6 * root.gather) / container.scale
            color: root.contentColor
            fill: root.selected || root.armed ? 1 : 0
        }

        MouseArea {
            id: area

            anchors.fill: parent

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // The pointer chooses as the arrows do, so there is only ever
            // the one selection to read.
            onContainsMouseChanged: if (containsMouse)
                root.menu.select(root.position)

            onClicked: root.menu.run(root.position)
        }
    }

    // Sized to the wider of the label and "Confirm", so arming a button
    // does not resize it and shove its neighbours about.
    TextMetrics {
        id: labelMetrics

        font: label.font
        text: root.action.label
    }

    TextMetrics {
        id: confirmMetrics

        font: label.font
        text: qsTr("Confirm")
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: container.bottom
        anchors.topMargin: Appearance.spacing.medium

        width: Math.ceil(Math.max(labelMetrics.advanceWidth, confirmMetrics.advanceWidth))
        horizontalAlignment: Text.AlignHCenter

        animate: true
        text: root.armed ? qsTr("Confirm") : root.action.label
        font.pixelSize: Appearance.font.normal
        font.weight: root.selected ? Font.DemiBold : Font.Normal
        color: root.armed ? Appearance.palette.m3error : root.selected ? Appearance.palette.m3onSurface : Appearance.palette.m3onSurfaceVariant

        opacity: root.menu.committing ? 0 : 1

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }
}
