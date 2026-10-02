pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import Morph.Blobs
import qs.components
import qs.config
import qs.services

// One screen of the lock: the wallpaper, the time in the top left and
// the password field just under the middle, laid out as hyprlock had
// them.
//
// The wallpaper is the same one the background draws, and the lock comes
// and goes over it: it dims and the clock and field rise in on the way
// in, and on the way out, after the tick, they fade and the dim lifts
// before the session is let go, so the desktop comes back under an
// unchanged picture.
WlSessionLockSurface {
    id: root

    required property Lock lock

    color: Appearance.palette.m3surface

    // Decoded before the first frame, not after: the compositor shows a
    // lock surface the moment it has one, and an async load would flash
    // plain surface first.
    Image {
        anchors.fill: parent

        source: Appearance.wallpaper ? `file://${Appearance.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false

        sourceSize.width: root.width * (root.screen?.devicePixelRatio ?? 1)
        sourceSize.height: root.height * (root.screen?.devicePixelRatio ?? 1)
    }

    Rectangle {
        anchors.fill: parent

        color: {
            const c = Appearance.palette.m3scrim;
            return Qt.rgba(c.r, c.g, c.b, 0.3);
        }

        opacity: content.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // The pointer is hidden, as hyprlock hid it; there is nothing here
    // to point at.
    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.BlankCursor
    }

    Item {
        id: content

        anchors.fill: parent

        // Up from the first frame, and down again once the password is
        // in, while the session is still locked.
        property bool shown: false
        Component.onCompleted: {
            shown = Qt.binding(() => !root.lock.leaving);
            forceActiveFocus();
        }

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.96

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Takes the keys for this screen. Every screen writes into the
        // lock's one buffer, so whichever has the keyboard, the field on
        // each shows the same.
        focus: true
        Keys.onPressed: event => {
            event.accepted = true;
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.lock.submit();
                return;
            case Qt.Key_Backspace:
                root.lock.erase(!!(event.modifiers & Qt.ControlModifier));
                return;
            case Qt.Key_Escape:
                root.lock.erase(true);
                return;
            }
            // Printable text only: no control characters, and no Ctrl
            // shortcuts typing their letter into the password.
            const text = event.text;
            if (text.length > 0 && text.charCodeAt(0) >= 0x20 && text !== "\x7f" && !(event.modifiers & Qt.ControlModifier))
                root.lock.type(text);
        }

        Column {
            x: 200
            y: 200

            spacing: -Appearance.spacing.small

            StyledText {
                text: Time.format("HH:mm")
                font.pixelSize: 120
                color: Appearance.palette.m3primaryFixed
            }

            StyledText {
                leftPadding: Appearance.padding.small
                text: Time.format("dddd d MMMM")
                font.pixelSize: Appearance.font.large
                color: Appearance.palette.m3primaryFixedDim
            }
        }

        // A ring that leaves the field's edge and spreads out as it fades,
        // after a wrong try.
        Rectangle {
            id: ring

            anchors.centerIn: field
            anchors.horizontalCenterOffset: field.anchors.horizontalCenterOffset

            rotation: field.rotation
            width: field.width
            height: field.height
            radius: height / 2
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

        // The field. It grows as the dots outrun it, swells a touch with
        // each key, wobbles to rest on a wrong password and, on the right
        // one, melts its dots together into a drop that shows the tick.
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 14 * Math.exp(-5 * shakeT) * Math.sin(shakeT * 7 * Math.PI)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 120

            readonly property color content: root.lock.unlocking ? Appearance.palette.m3onSuccess : root.lock.wrong ? Appearance.palette.m3onError : Appearance.palette.m3onTertiary

            readonly property int dotSize: 10
            readonly property int step: dotSize + Appearance.spacing.small

            // Runs 0 to 1 over a shake. The offset above is a spring let
            // go: a swing that dies away, landing back on zero at 1.
            property real shakeT: 1

            // A key's push on the field: out for a character in, in for
            // one taken away, and back with a little give either way.
            property real bump: 0
            property real bumpSign: 1

            // The right password, in three overlapping parts: the dots
            // go soft enough to run together, a drop swells in the
            // middle for them to pour into, and it wobbles as it fills.
            property real melt: 0
            property real swell: 0
            property real wobble: 1

            // How many dots join the goo. The blob shader blends a
            // limited number of shapes at once; the rest just shrink
            // into the drop.
            readonly property int gooDots: 14

            implicitWidth: Math.max(200, dots.implicitWidth + Appearance.padding.extraLarge * 2)
            implicitHeight: 60

            radius: height / 2
            color: root.lock.unlocking ? Appearance.palette.m3success : root.lock.wrong ? Appearance.palette.m3error : Appearance.palette.m3tertiary

            // Leans with the swing, as a head shaken rather than slid.
            rotation: anchors.horizontalCenterOffset * 0.15
            scale: 1 + bump * bumpSign * 0.04

            Behavior on implicitWidth {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on color {
                CAnim {
                    duration: Appearance.anim.durations.fastEffects
                }
            }

            function push(sign: real): void {
                bumpSign = sign;
                pushAnim.restart();
            }

            SequentialAnimation {
                id: pushAnim

                NumberAnimation {
                    target: field
                    property: "bump"
                    to: 1
                    duration: 60
                    easing.type: Easing.OutQuad
                }
                Anim {
                    target: field
                    property: "bump"
                    to: 0
                    type: Anim.FastSpatial
                }
            }

            NumberAnimation {
                id: shake

                target: field
                property: "shakeT"
                from: 0
                to: 1
                duration: 650
            }

            Connections {
                target: root.lock

                function onFailed(): void {
                    shake.restart();
                    ring.burst(Appearance.palette.m3error);
                }

                function onUnlockingChanged(): void {
                    if (root.lock.unlocking) {
                        success.restart();
                    } else {
                        success.stop();
                        dotModel.clear();
                        field.melt = 0;
                        field.swell = 0;
                        field.wobble = 1;
                        check.shown = 0;
                    }
                }

                // The dots follow the buffer. Those that go are handed to
                // ghosts that play their way out, so a backspace, a clear
                // and a wrong try each look like what they are; on the
                // right password the dots stay put and gather instead.
                function onBufferChanged(): void {
                    if (root.lock.unlocking)
                        return;

                    const n = root.lock.buffer.length;
                    const old = dotModel.count;

                    if (n < old) {
                        const mode = n === 0 && root.lock.wrong ? Ghost.Fall : n === 0 && old > 1 ? Ghost.Clear : Ghost.Erase;
                        for (let i = n; i < old; i++) {
                            const dot = dotRepeater.itemAt(i);
                            if (!dot)
                                continue;
                            const at = dot.mapToItem(content, 0, -dot.lift);
                            ghost.createObject(content, {
                                x: at.x,
                                y: at.y,
                                size: field.dotSize,
                                mode: mode,
                                order: mode === Ghost.Clear ? old - 1 - i : i,
                                startScale: Math.min(1, dot.born) * field.scale
                            });
                        }
                        dotModel.remove(n, old - n);
                        if (mode !== Ghost.Fall)
                            field.push(-0.5);
                    } else if (n > old) {
                        while (dotModel.count < n)
                            dotModel.append({});
                        field.push(1);
                    }
                }
            }

            BlobGroup {
                id: goo

                color: field.content
                smoothing: 2 + 16 * field.melt
            }

            ParallelAnimation {
                id: success

                NumberAnimation {
                    target: field
                    property: "melt"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 100
                    }
                    Anim {
                        target: field
                        property: "swell"
                        from: 0
                        to: 1
                        type: Anim.SlowSpatial
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 300
                    }
                    NumberAnimation {
                        target: field
                        property: "wobble"
                        from: 0
                        to: 1
                        duration: 750
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 340
                    }
                    Anim {
                        target: check
                        property: "shown"
                        to: 1
                        type: Anim.FastSpatial
                    }
                }
            }

            // The drop the dots pour into. It jiggles as a spring let go,
            // wide then tall then wide, losing a little each time.
            BlobRect {
                readonly property real size: 36 * field.swell
                readonly property real jiggle: field.wobble < 1 ? 0.16 * Math.exp(-4 * field.wobble) * Math.sin(field.wobble * 6 * Math.PI) : 0

                x: (field.width - width) / 2
                y: (field.height - height) / 2
                width: size * (1 + jiggle)
                height: size * (1 - jiggle)

                group: root.lock.unlocking ? goo : null
                radius: Math.min(width, height) / 2
                deformScale: 0
            }

            // One dot per character, each dropping in on its own. A list
            // model rather than a count, so a keystroke adds one dot
            // instead of rebuilding the row.
            ListModel {
                id: dotModel
            }

            Item {
                id: dots

                anchors.centerIn: parent

                implicitWidth: Math.max(0, dotModel.count * field.step - Appearance.spacing.small)
                implicitHeight: field.dotSize

                // Eased to its new width, so the row slides over to stay
                // centred rather than jumping half a dot each key.
                width: implicitWidth
                height: implicitHeight

                Behavior on width {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                // A wave rolling along the dots while PAM is checking.
                // Its height eases in and out, so the dots settle rather
                // than freeze mid-hop when the answer comes.
                property real phase: 0
                property real amplitude: root.lock.checking ? 6 : 0

                Behavior on amplitude {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                NumberAnimation on phase {
                    running: dots.amplitude > 0
                    from: 0
                    to: 2 * Math.PI
                    duration: 900
                    loops: Animation.Infinite
                }

                Repeater {
                    id: dotRepeater

                    model: dotModel

                    Item {
                        id: dot

                        required property int index

                        x: Math.max(0, index) * field.step
                        width: field.dotSize
                        height: field.dotSize

                        // Only the crest of the wave: each dot hops up and
                        // comes back down to the line, never below it.
                        readonly property real lift: dots.amplitude * Math.max(0, Math.sin(dots.phase - Math.max(0, index) * 0.6))

                        // 0 to 1 on arrival, overshooting a little on the
                        // way. Past 1 the blob squashes, short of it it
                        // stretches. The first dot drops in; every one
                        // after splits off the dot before it, sliding out
                        // sideways with a neck between them that thins
                        // and breaks as they part.
                        property real born: 0
                        readonly property real stretch: 1 - born
                        readonly property bool splits: index > 0
                        readonly property bool joinsGoo: index < field.gooDots

                        // 0 to 1 as the dots draw in to the middle on the
                        // right password, the outer ones a beat after.
                        property real gather: 0
                        readonly property real centre: (dots.width - field.dotSize) / 2

                        Component.onCompleted: born = 1

                        Behavior on born {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }

                        Connections {
                            target: root.lock

                            function onUnlockingChanged(): void {
                                if (root.lock.unlocking)
                                    gatherAnim.restart();
                            }
                        }

                        SequentialAnimation {
                            id: gatherAnim

                            PauseAnimation {
                                duration: Math.abs(dot.x - dot.centre) / field.step * 18
                            }
                            NumberAnimation {
                                target: dot
                                property: "gather"
                                to: 1
                                duration: 320
                                easing.type: Easing.InOutCubic
                            }
                        }

                        // The neck, from the dot before to this one's
                        // middle, gone by the time they have parted.
                        Rectangle {
                            visible: dot.splits && height > 0.5

                            x: field.dotSize / 2 - field.step
                            anchors.verticalCenter: parent.verticalCenter

                            width: field.step * Math.max(0, Math.min(1, dot.born))
                            height: field.dotSize * 0.7 * Math.max(0, 1 - dot.born * 1.3)
                            radius: height / 2
                            color: field.content
                        }

                        Rectangle {
                            id: blob

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (dot.centre - dot.x) * dot.gather - (dot.splits ? field.step * dot.stretch : 0)
                            anchors.verticalCenterOffset: -dot.lift - (dot.splits ? 0 : 10 * dot.stretch)

                            width: field.dotSize * (dot.splits ? 1 + 0.7 * dot.stretch : 1 - 0.35 * dot.stretch) + dot.lift * 0.15
                            height: field.dotSize * (dot.splits ? 1 - 0.3 * dot.stretch : 1 + 0.6 * dot.stretch) + dot.lift * 0.3
                            radius: Math.min(width, height) / 2
                            color: field.content

                            scale: Math.max(0, Math.min(1, dot.splits ? 0.5 + dot.born * 0.5 : dot.born * 1.4)) * (1 - 0.4 * dot.gather)

                            // Handed over to the goo on the right password,
                            // or, past what it can take, shrunk away into
                            // the drop.
                            visible: !(root.lock.unlocking && dot.joinsGoo)
                            opacity: dot.joinsGoo ? 1 : 1 - Math.max(0, dot.gather - 0.7) / 0.3
                        }

                        // The same dot as goo, stretching as it runs in
                        // and fusing with its neighbours on the way.
                        BlobRect {
                            x: blob.x + blob.width * (1 - blob.scale) / 2
                            y: blob.y + blob.height * (1 - blob.scale) / 2
                            width: blob.width * blob.scale
                            height: blob.height * blob.scale

                            group: root.lock.unlocking && dot.joinsGoo ? goo : null
                            radius: Math.min(width, height) / 2
                            deformScale: 0.0012
                        }
                    }
                }
            }

            MaterialSymbol {
                id: check

                anchors.centerIn: parent

                // 0 to 1 as the drop fills, overshooting a touch. Cut out
                // of the drop in the field's own colour.
                property real shown: 0

                icon: "check"
                size: Appearance.font.icon.normal
                weight: 700
                color: field.color

                opacity: Math.min(1, shown * 2)
                scale: 0.3 + 0.7 * shown
                rotation: -45 * (1 - shown)
            }
        }

        // A dot on its way out, left behind where a real one stood so the
        // row can close up underneath it at once.
        Component {
            id: ghost

            Ghost {
                color: field.content
            }
        }

        // Under the field: the warning after a wrong try, or what PAM had
        // to add.
        StyledText {
            anchors.horizontalCenter: field.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: Appearance.spacing.medium

            text: root.lock.message || (root.lock.wrong ? qsTr("Wrong password, try again") : "")
            font.pixelSize: Appearance.font.normal
            color: Appearance.palette.m3error
        }
    }
}
