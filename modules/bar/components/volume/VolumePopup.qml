import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// The output's panel: a wavy level slider, the glyph as a mute button,
// and whichever device is being fed -- and under it, folded away until
// asked for, either a picker of the outputs and inputs to use or a mixer
// of the applications playing into the output.
//
// The mixer is a row of faders after the Android volume panel's
// expanded form: a tall pill per application, filled from the bottom to
// its level, with the application's icon sitting in the fill's base.
// The fill never shrinks past the circle around the icon, so the icon
// is always the handle to grab, and the button that mutes. Inside the
// fill a lighter band follows what the stream is actually putting out,
// so the one that is making the noise can be told at a glance.
BlobPopup {
    id: root

    readonly property int panelWidth: 320

    // Which section is unfolded -- "devices", "mixer" or neither. One
    // at a time, so the panel never grows taller than either alone.
    // Remembered between openings: someone who reaches for the mixer
    // tends to want it every time.
    property string section: ""

    readonly property bool mixerShown: open && section === "mixer"

    readonly property int faderWidth: 52
    readonly property int faderHeight: 148
    readonly property int faderSpacing: Appearance.spacing.small

    // Held to one width open or shut: the panel follows its content's
    // height smoothly, but snaps to a new width.
    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: content.implicitHeight

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                // The glyph doubles as the mute button -- the same thing the
                // bar widget's middle click does.
                MaterialSymbol {
                    id: icon

                    Layout.alignment: Qt.AlignVCenter

                    icon: Audio.icon
                    size: Appearance.font.icon.large
                    color: Audio.muted ? Appearance.palette.m3error : Appearance.palette.m3primary
                    fill: Audio.muted ? 1 : 0

                    opacity: iconHover.hovered ? 1 : 0.85

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    HoverHandler {
                        id: iconHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Audio.toggleMute()
                    }
                }

                WavySlider {
                    id: slider

                    Layout.fillWidth: true

                    // Flat when there is nothing to hear, travelling when
                    // there is -- the same rule the media slider follows
                    // for paused and playing.
                    wavy: !Audio.muted && Audio.volume > 0
                    activeColor: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3primary

                    // Live rather than committed on release, as the media
                    // slider is: a volume you cannot hear until you let go
                    // is one you have to set twice.
                    onMoved: Audio.setVolume(value)

                    // Follows the sink only while the handle is not being
                    // dragged, so an external change -- a media key, another
                    // mixer -- moves it without fighting the pointer.
                    Binding on value {
                        when: !slider.pressed
                        value: Audio.volume
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 40

                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.volume * 100) + "%"
                    color: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true

                    animate: true
                    text: Audio.description || qsTr("No output")
                    color: Appearance.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                // Opens the device picker: no count, since there is
                // always at least the one being fed.
                SectionChip {
                    icon: "speaker_group"
                    open: root.section === "devices"

                    onToggled: root.section = open ? "" : "devices"
                }

                // Opens the mixer, carrying how many are playing, so it
                // is worth opening before it is opened.
                SectionChip {
                    icon: "tune"
                    label: Audio.streams.length
                    open: root.section === "mixer"

                    onToggled: root.section = open ? "" : "mixer"
                }
            }

            // The device picker: every output, then every input, the
            // default of each on its pill. Laid out only while open, as
            // the mixer is.
            ColumnLayout {
                visible: root.section === "devices"

                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                spacing: Appearance.spacing.extraSmall

                StyledText {
                    Layout.leftMargin: Appearance.padding.medium

                    text: qsTr("Output")
                    color: Appearance.palette.m3primary
                    font.weight: Font.Medium
                }

                Repeater {
                    model: ScriptModel {
                        values: Audio.sinks
                    }

                    AudioDeviceItem {
                        active: modelData === Audio.sink

                        onChosen: Audio.setSink(modelData)
                    }
                }

                StyledText {
                    Layout.leftMargin: Appearance.padding.medium
                    Layout.topMargin: Appearance.spacing.small

                    text: qsTr("Input")
                    color: Appearance.palette.m3primary
                    font.weight: Font.Medium
                }

                // The default input's level, laid out as the output's is
                // at the head of the panel: the glyph mutes, the slider
                // moves live and lets go of the value while dragged.
                RowLayout {
                    visible: Audio.micAvailable

                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.padding.medium
                    Layout.bottomMargin: Appearance.spacing.extraSmall
                    spacing: Appearance.spacing.medium

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter

                        icon: Audio.micMuted ? "mic_off" : "mic"
                        color: Audio.micMuted ? Appearance.palette.m3error : Appearance.palette.m3primary
                        fill: Audio.micMuted ? 1 : 0

                        opacity: micIconHover.hovered ? 1 : 0.85

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        HoverHandler {
                            id: micIconHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Audio.toggleMicMute()
                        }
                    }

                    WavySlider {
                        id: micSlider

                        Layout.fillWidth: true

                        wavy: !Audio.micMuted && Audio.micVolume > 0
                        activeColor: Audio.micMuted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3primary

                        onMoved: Audio.setMicVolume(value)

                        Binding on value {
                            when: !micSlider.pressed
                            value: Audio.micVolume
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 40

                        horizontalAlignment: Text.AlignRight
                        text: Math.round(Audio.micVolume * 100) + "%"
                        color: Audio.micMuted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: Audio.sources
                    }

                    AudioDeviceItem {
                        active: modelData === Audio.source

                        onChosen: Audio.setSource(modelData)
                    }
                }

                StyledText {
                    Layout.leftMargin: Appearance.padding.medium

                    visible: Audio.sources.length === 0

                    text: qsTr("No microphones")
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }

            // The mixer. Laid out only while open: the panel follows the
            // content's height, so it grows down to take it in and draws
            // back up when it goes.
            Item {
                visible: root.section === "mixer"

                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                implicitHeight: Audio.streams.length > 0 ? faders.contentHeight : empty.implicitHeight

                // Centred while they fit and scrolled sideways once they do
                // not, rather than squeezed.
                Flickable {
                    id: faders

                    anchors.fill: parent

                    visible: Audio.streams.length > 0

                    contentWidth: Math.max(width, row.implicitWidth)
                    contentHeight: row.implicitHeight
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: row.implicitWidth > width
                    clip: true

                    Row {
                        id: row

                        x: Math.max(0, (faders.width - implicitWidth) / 2)
                        spacing: root.faderSpacing

                        Repeater {
                            model: ScriptModel {
                                values: Audio.streams
                            }

                            Fader {
                                mixerShown: root.mixerShown
                                faderWidth: root.faderWidth
                                faderHeight: root.faderHeight
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: empty

                    anchors.centerIn: parent

                    visible: Audio.streams.length === 0
                    spacing: Appearance.spacing.extraSmall

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter

                        icon: "music_off"
                        size: Appearance.font.icon.large
                        color: Appearance.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Appearance.padding.small

                        text: qsTr("Nothing is playing")
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
