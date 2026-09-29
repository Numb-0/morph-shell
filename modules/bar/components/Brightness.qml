import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the backlight glyph and its level. Click opens the panel,
// and the wheel sets the level without opening anything.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    // Boxed rather than sized to the number, as the battery and the
    // volume are, so crossing 100% does not shuffle the bar.
    readonly property int labelWidth: 36

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            glyph.press();
            root.clicked();
        }
    }

    WheelHandler {
        // Scaled by the delta rather than stepped per event, as the
        // volume is: a mouse notch is 120 and lands on a twentieth,
        // while a touchpad sends a stream of much smaller deltas.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => Backlight.changeBrightness(event.angleDelta.y / 120 * 0.05)
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.extraSmall

        MaterialSymbol {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter

            icon: Backlight.icon
            size: Appearance.font.icon.normal

            // There is no state here worth calling out the way mute or a
            // flat battery is, so FILL carries the level instead: the sun
            // solidifies as the panel brightens. The axis does not change
            // the glyph's advance, so the row does not move while it
            // fills.
            fill: Backlight.brightness
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            width: root.labelWidth
            horizontalAlignment: Text.AlignRight

            text: Math.round(Backlight.brightness * 100) + "%"
        }
    }
}
