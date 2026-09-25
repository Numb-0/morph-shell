import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The backlight's panel: the glyph, a level slider, and the number.
// Everything about how it grows out of the bar lives in BlobPopup.
BlobPopup {
    id: root

    RowLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter

            icon: Backlight.icon
            size: Appearance.font.icon.large
            color: Appearance.palette.primary

            // As in the bar: FILL rides the level rather than marking a
            // state, so the sun fills as the panel brightens.
            fill: Backlight.brightness
        }

        WavySlider {
            id: slider

            Layout.fillWidth: true
            Layout.preferredWidth: 220

            // Flat, unlike the volume and the media sliders. The wave
            // means something is travelling -- a track playing, sound
            // coming out -- and a lit panel is not going anywhere.
            wavy: false

            // Live rather than committed on release: brightness you
            // cannot see until you let go is brightness you set twice.
            onMoved: Backlight.setBrightness(value)

            // Follows the backlight only while the handle is not being
            // dragged, so a brightness key pressed mid-drag does not
            // fight the pointer.
            Binding on value {
                when: !slider.pressed
                value: Backlight.brightness
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40

            horizontalAlignment: Text.AlignRight
            text: Math.round(Backlight.brightness * 100) + "%"
        }
    }
}
