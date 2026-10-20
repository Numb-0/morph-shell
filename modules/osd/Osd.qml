import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Morph.Blobs
import qs.components
import qs.config
import qs.services.session
import qs.services.system
import qs.states

// A glance at whatever just changed -- the volume or the brightness as a
// level, the microphone, Caps Lock, staying awake, the keyboard layout
// or the power profile as a glyph and a word -- floating over the bottom of the
// screen and going away again once it has been left alone.
//
// It is one blob, and it moves like one. It comes up out of the bottom
// edge as a drop and spreads out into a pill; going from one reading to
// another stretches or shrinks that same pill to the new one's size, the
// old reading sliding up and out as the new one slides up into place.
// Every change of a reading gives it a little hop, which the blob's
// springs turn into a squash, and a toggle turned on throws a droplet off
// its top -- turned off, the droplet falls back in.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property real pillHeight: Appearance.font.icon.large + Appearance.padding.medium * 2

        // How far the droplet flies off the top before it is gone.
        readonly property real dropTravel: pillHeight * 0.9
        readonly property real dropSize: pillHeight * 0.38

        // As wide as the reading shown wants. Follows it with a spatial
        // curve while up, so the pill overshoots its new width a little
        // and settles; snaps while down, so it comes up already sized
        // for what it is showing.
        readonly property real targetWidth: (contents.current?.implicitWidth ?? 0) + Appearance.padding.large * 2

        property real width_: targetWidth

        Behavior on width_ {
            enabled: win.reveal > 0

            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Up out of the edge as a drop, then out sideways into the pill:
        // two motions, one after the other, rather than one that does
        // both at once.
        property real reveal: 0
        property real stretch: 0

        // A key press's worth of hop. Small, and over before the next key
        // repeat; the blob's springs make it read as a squash.
        property real hop: 0

        // The droplet's way off the top: 0 inside the pill, 1 gone.
        property real drop: 0

        // Holds the states: a window has none of its own.
        Item {
            states: State {
                name: "shown"
                when: OsdState.shown

                PropertyChanges {
                    win.reveal: 1
                    win.stretch: 1
                }
            }

            transitions: [
                Transition {
                    to: "shown"

                    SequentialAnimation {
                        Anim {
                            target: win
                            property: "reveal"
                            type: Anim.Emphasized
                            duration: Appearance.anim.durations.fastSpatial
                        }
                        Anim {
                            target: win
                            property: "stretch"
                            type: Anim.SlowSpatial
                        }
                    }
                },
                Transition {
                    from: "shown"

                    SequentialAnimation {
                        Anim {
                            target: win
                            property: "stretch"
                            type: Anim.Emphasized
                            duration: Appearance.anim.durations.slowEffects
                        }
                        Anim {
                            target: win
                            property: "reveal"
                            type: Anim.Emphasized
                            duration: Appearance.anim.durations.slowEffects
                        }
                    }
                }
            ]
        }

        SequentialAnimation {
            id: hopAnim

            Anim {
                target: win
                property: "hop"
                to: -Appearance.spacing.small
                duration: 70
                type: Anim.Standard
            }
            Anim {
                target: win
                property: "hop"
                to: 0
                type: Anim.FastSpatial
            }
        }

        Anim {
            id: dropAnim

            target: win
            property: "drop"
            type: Anim.Standard
            duration: Appearance.anim.durations.slowSpatial
        }

        Connections {
            target: OsdState

            function onPoked(kind: string): void {
                hopAnim.restart();

                if (kind === "volume" || kind === "brightness")
                    return;

                // Off the top for on, back in from above for off. Layout
                // and profile have no off: theirs always goes up.
                dropAnim.stop();
                win.drop = OsdState.active ? 0 : 1;
                dropAnim.to = OsdState.active ? 1 : 0;
                dropAnim.start();
            }
        }

        screen: modelData
        color: "transparent"
        visible: reveal > 0

        // Above everything, reserving nothing and taking no input: it is
        // there to be read, never to be in the way of a click. The whole
        // width, so a long layout name never has the pill outgrow it.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "morph-shell-osd"
        exclusiveZone: 0
        mask: Region {}

        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // Room above the pill for the droplet to fly into.
        implicitHeight: Config.osd.margin + pillHeight + dropTravel + dropSize + Appearance.spacing.large

        // The droplet only ever fuses with the pill, so the pair have a
        // group of their own.
        BlobGroup {
            id: group

            color: Colours.palette.m3surfaceContainer
            smoothing: Appearance.border.smoothing
        }

        // Sits under its resting place by its own height and the margin
        // at nothing, so it rises up from below the screen edge.
        BlobRect {
            id: pill

            readonly property real restY: win.height - Config.osd.margin - win.pillHeight

            x: (win.width - width) / 2
            y: restY + (Config.osd.margin + win.pillHeight) * (1 - win.reveal) + win.hop

            implicitWidth: win.pillHeight + Math.max(0, win.width_ - win.pillHeight) * win.stretch
            implicitHeight: win.pillHeight

            group: group
            radius: win.pillHeight / 2
        }

        // Starts and ends inside the pill, where the group fuses it in,
        // and is full size until it is most of the way up, so it pinches
        // off the top rather than shrinking away from it.
        BlobRect {
            id: droplet

            readonly property real size: win.dropSize * Math.min(1, (1 - win.drop) / 0.35)

            visible: size > 0.5 && win.drop > 0

            x: pill.x + pill.width / 2 - width / 2
            y: pill.y + win.pillHeight / 2 - win.dropTravel * win.drop - height / 2

            implicitWidth: size
            implicitHeight: size

            group: group
            radius: size / 2
        }

        // Clipped to the pill, so a reading is uncovered as the pill
        // spreads out rather than drawn past its ends.
        Item {
            id: contents

            // The reading on show, for the pill to size itself to.
            readonly property Item current: {
                for (const reading of [volume, brightness, mic, caps, awake, layout, profile])
                    if (reading.kind === OsdState.kind)
                        return reading;
                return null;
            }

            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height

            clip: true
            opacity: Math.min(1, win.stretch * 1.5)

            Level {
                id: volume

                kind: "volume"
                icon: Audio.icon
                value: Audio.volume
                muted: Audio.muted
            }

            Level {
                id: brightness

                kind: "brightness"
                icon: Backlight.icon
                value: Backlight.brightness
            }

            Toggle {
                id: mic

                kind: "mic"
                icon: Audio.micMuted ? "mic_off" : "mic"
                text: Audio.micMuted ? qsTr("Microphone muted") : qsTr("Microphone on")
                lit: Audio.micMuted
                litColor: Colours.palette.m3error
            }

            Toggle {
                id: caps

                kind: "caps"
                icon: "keyboard_capslock"
                text: OsdState.capsLock ? qsTr("Caps Lock on") : qsTr("Caps Lock off")
                lit: OsdState.capsLock
            }

            Toggle {
                id: awake

                kind: "awake"
                icon: "coffee"
                text: Idle.awake ? qsTr("Staying awake") : qsTr("Idling as usual")
                lit: Idle.awake
            }

            Toggle {
                id: layout

                kind: "layout"
                icon: "keyboard"
                text: OsdState.layout
                lit: true
            }

            Toggle {
                id: profile

                kind: "profile"
                icon: Profiles.icon
                text: Profiles.label
                lit: true
            }
        }

        // One reading in the pill. The one on show sits in the middle;
        // the rest wait, invisible, below it. Taking over, a reading
        // slides up from below into the middle and the one it replaces
        // goes on up and out, both fading, so the change reads as the
        // pill rolling over to the next.
        component Reading: Item {
            id: reading

            required property string kind

            readonly property bool current: OsdState.kind === kind

            // -1 gone up, 0 in place, 1 waiting below.
            property real shift: current ? 0 : 1

            default property alias content: row.data
            implicitWidth: row.implicitWidth

            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) / 2
            width: implicitWidth
            height: row.implicitHeight

            opacity: 1 - Math.abs(shift)
            visible: opacity > 0

            // Half the pill's height: out of sight by the time it has
            // faded, without flying any further than it needs to.
            transform: Translate {
                y: reading.shift * (reading.parent?.height ?? 0) * 0.5
            }

            onCurrentChanged: {
                shiftAnim.stop();
                if (current) {
                    shift = 1;
                    shiftAnim.to = 0;
                } else {
                    shiftAnim.to = -1;
                }
                shiftAnim.start();
            }

            Anim {
                id: shiftAnim

                target: reading
                property: "shift"
                type: Anim.DefaultSpatial
            }

            RowLayout {
                id: row

                spacing: Appearance.spacing.medium
            }
        }

        // A level: its glyph, the slider the bar's panels use, and the
        // number.
        component Level: Reading {
            id: level

            required property string icon
            required property real value
            property bool muted: false

            MaterialSymbol {
                id: levelIcon

                Layout.alignment: Qt.AlignVCenter

                icon: level.icon
                size: Appearance.font.icon.large
                color: level.muted ? Colours.palette.m3error : Colours.palette.m3primary
                fill: level.muted ? 1 : 0
            }

            // Read-only here: the window takes no input.
            WavySlider {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignVCenter

                value: level.value
                wavy: !level.muted && level.value > 0

                // The window unmapping does not hide its items, so the
                // wave is stopped by hand while the OSD is going or
                // showing something else.
                animateWave: wavy && OsdState.shown && level.current
                activeColor: level.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 40

                horizontalAlignment: Text.AlignRight
                text: Math.round(level.value * 100) + "%"
                font.pixelSize: Appearance.font.normal
                color: level.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
            }
        }

        // A toggle: its glyph, solid and coloured while on, and what it
        // is now. The glyph is pressed on each change, as a bar icon is
        // on a click.
        component Toggle: Reading {
            id: toggle

            required property string icon
            required property string text
            property bool lit: false
            property color litColor: Colours.palette.m3primary

            Connections {
                target: OsdState

                function onPoked(kind: string): void {
                    if (kind === toggle.kind)
                        toggleIcon.press();
                }
            }

            MaterialSymbol {
                id: toggleIcon

                Layout.alignment: Qt.AlignVCenter

                icon: toggle.icon
                size: Appearance.font.icon.large
                color: toggle.lit ? toggle.litColor : Colours.palette.m3onSurfaceVariant
                fill: toggle.lit ? 1 : 0
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Appearance.padding.small

                text: toggle.text
                font.pixelSize: Appearance.font.normal
                color: Colours.palette.m3onSurface
            }
        }
    }
}
