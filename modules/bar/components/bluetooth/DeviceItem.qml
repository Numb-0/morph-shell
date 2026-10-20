import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config
import qs.services.system

Rectangle {
    id: item

    required property var modelData

    readonly property bool active: modelData.connected
    readonly property bool busy: Bt.busy(modelData)

    readonly property string status: {
        if (modelData.pairing)
            return qsTr("Pairing…");
        if (modelData.state === BluetoothDeviceState.Connecting)
            return qsTr("Connecting…");
        if (modelData.state === BluetoothDeviceState.Disconnecting)
            return qsTr("Disconnecting…");
        if (active)
            return modelData.batteryAvailable ? qsTr("Connected · %1%").arg(Math.round(modelData.battery * 100)) : qsTr("Connected");
        if (modelData.paired)
            return qsTr("Paired");
        return "";
    }

    Layout.fillWidth: true
    implicitHeight: 44

    // The connected ones sit on a tonal pill, as the joined network
    // does; the rest only light up under the pointer.
    radius: height / 2
    color: active ? Colours.palette.m3secondaryContainer : itemHover.hovered ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"

    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: itemHover

        cursorShape: item.active || item.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    // The whole row connects -- pairing first, for a stranger.
    // Leaving is its own button, so a stray click on the row does
    // not drop the headphones mid-call.
    TapHandler {
        onTapped: if (!item.active)
            Bt.toggle(item.modelData)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.medium
        anchors.rightMargin: Appearance.padding.extraSmall
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            icon: Bt.deviceIcon(item.modelData)
            color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            fill: item.active ? 1 : 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true

                text: item.modelData.name
                font.pixelSize: Appearance.font.normal
                font.weight: item.active ? Font.Medium : Font.Normal
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                visible: text !== ""

                animate: true
                text: item.status
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        // Forget, for anything paired and not in the middle of
        // something. It unpairs outright, so it stays out of the
        // way in the muted colour rather than the accent.
        IconButton {
            visible: item.modelData.paired && !item.busy

            icon: "delete"
            color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant

            onActivated: Bt.forget(item.modelData)
        }

        // Disconnect, for the connected; a spinner while anything is
        // under way; nothing otherwise, since the whole row is the
        // button.
        Item {
            visible: item.active || item.busy

            implicitWidth: 32
            implicitHeight: 32

            IconButton {
                anchors.fill: parent

                visible: item.active && !item.busy

                icon: "link_off"
                color: Colours.palette.m3primary

                onActivated: Bt.toggle(item.modelData)
            }

            MaterialSymbol {
                anchors.centerIn: parent

                visible: item.busy

                icon: "progress_activity"
                size: Appearance.font.icon.small
                color: Colours.palette.m3primary

                RotationAnimation on rotation {
                    running: item.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }
    }
}
