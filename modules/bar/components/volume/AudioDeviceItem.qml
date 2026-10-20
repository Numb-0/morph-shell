import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services.system

// One output or input in the panel's picker: the current default sits
// on a tonal pill, as the joined network does, and any other is made
// the default by clicking it.
Rectangle {
    id: item

    required property PwNode modelData
    required property bool active

    signal chosen

    Layout.fillWidth: true
    implicitHeight: 40

    radius: height / 2
    color: active ? Appearance.palette.m3secondaryContainer : itemHover.hovered ? Qt.alpha(Appearance.palette.m3onSurface, 0.08) : "transparent"

    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: itemHover

        cursorShape: item.active ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: if (!item.active)
            item.chosen()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.medium
        anchors.rightMargin: Appearance.padding.medium
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            icon: Audio.deviceIcon(item.modelData)
            color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
            fill: item.active ? 1 : 0
        }

        StyledText {
            Layout.fillWidth: true

            text: Audio.deviceName(item.modelData)
            font.pixelSize: Appearance.font.normal
            font.weight: item.active ? Font.Medium : Font.Normal
            color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
            elide: Text.ElideRight
        }

        MaterialSymbol {
            visible: item.active

            icon: "check"
            size: Appearance.font.icon.small
            color: Appearance.palette.m3onSecondaryContainer
        }
    }
}
