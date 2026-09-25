import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the output glyph and its level. Click opens the panel,
// middle click mutes, and the wheel sets the volume without opening
// anything.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    readonly property color accent: Audio.muted ? Appearance.palette.subtext : Appearance.palette.text

    // As with the battery: boxed rather than sized to the number, so
    // crossing 100% does not shuffle the bar.
    readonly property int labelWidth: 36

    implicitWidth: row.implicitWidth + Appearance.padding.large * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        onTapped: Audio.toggleMute()
    }

    WheelHandler {
        // Scaled by the delta rather than stepped per event: a mouse
        // notch is 120 and lands on a twentieth, while a touchpad sends
        // a stream of much smaller deltas that would otherwise take the
        // volume end to end in a flick.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => Audio.changeVolume(event.angleDelta.y / 120 * 0.05)
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.extraSmall

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            icon: Audio.icon
            size: Appearance.font.icon.small
            color: root.accent

            // Muted is the state worth seeing at a glance, so it is the
            // one that fills.
            fill: Audio.muted ? 1 : 0
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            width: root.labelWidth
            horizontalAlignment: Text.AlignRight

            text: Math.round(Audio.volume * 100) + "%"
            color: root.accent
        }
    }
}
