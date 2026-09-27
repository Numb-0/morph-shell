import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The output's panel: a wavy level slider, the glyph as a mute button,
// and whichever device is being fed.
BlobPopup {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
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
                Layout.preferredWidth: 220

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

        StyledText {
            Layout.fillWidth: true
            Layout.maximumWidth: 320

            animate: true
            text: Audio.description || qsTr("No output")
            color: Appearance.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
