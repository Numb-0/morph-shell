import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config
import qs.services

// The Bluetooth panel: the radio's switch, and the devices to connect,
// pair or forget.
//
// Laid out as the network panel is -- a tonal card with the switch, a
// count, the list -- rather than as caelestia's, whose switches for
// power and discovery sit in a column of their own. Discovery here just
// runs while the panel is open, as the Wi-Fi scanner does.
BlobPopup {
    id: root

    // As many as the network panel shows. Past that it is almost always
    // strangers' devices that discovery has turned up.
    readonly property int maxDevices: 7

    readonly property int panelWidth: 300

    onOpenChanged: Bt.watch(open)

    Component.onDestruction: if (open)
        Bt.watch(false)

    // A round, borderless icon button with an M3 state layer.
    component IconButton: Item {
        id: btn

        required property string icon
        property color color: Appearance.palette.m3onSurface

        signal activated

        implicitWidth: 32
        implicitHeight: 32

        HoverHandler {
            id: btnHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: btn.activated()
        }

        Rectangle {
            anchors.fill: parent

            radius: width / 2
            color: btn.color
            opacity: btnHover.hovered ? 0.12 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent

            icon: btn.icon
            size: Appearance.font.icon.small
            color: btn.color
        }
    }

    component DeviceItem: Rectangle {
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
        color: active ? Appearance.palette.m3secondaryContainer : itemHover.hovered ? Qt.alpha(Appearance.palette.m3onSurface, 0.08) : "transparent"

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
                color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
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
                    color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true

                    visible: text !== ""

                    animate: true
                    text: item.status
                    color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Forget, for anything paired and not in the middle of
            // something. It unpairs outright, so it stays out of the
            // way in the muted colour rather than the accent.
            IconButton {
                visible: item.modelData.paired && !item.busy

                icon: "delete"
                color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurfaceVariant

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
                    color: Appearance.palette.m3primary

                    onActivated: Bt.toggle(item.modelData)
                }

                MaterialSymbol {
                    anchors.centerIn: parent

                    visible: item.busy

                    icon: "progress_activity"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3primary

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

    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            // The switch on its own tonal card, as the Wi-Fi one is.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56

                radius: Appearance.rounding.extraLarge
                color: Bt.enabled ? Appearance.palette.m3primaryContainer : Appearance.palette.m3surfaceContainerHigh

                Behavior on color {
                    CAnim {}
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.medium
                    spacing: Appearance.spacing.medium

                    MaterialSymbol {
                        icon: Bt.icon
                        size: Appearance.font.icon.normal
                        color: Bt.enabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                        fill: Bt.enabled ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: qsTr("Bluetooth")
                            font.pixelSize: Appearance.font.normal
                            font.weight: Font.Medium
                            color: Bt.enabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true

                            animate: true
                            text: {
                                if (!Bt.available)
                                    return qsTr("No adapter");
                                if (Bt.blocked)
                                    return qsTr("Blocked by hardware switch");
                                if (!Bt.enabled)
                                    return qsTr("Off");
                                const n = Bt.connectedDevices.length;
                                if (n === 1)
                                    return Bt.connectedDevices[0].name;
                                if (n > 1)
                                    return qsTr("%1 devices connected").arg(n);
                                return qsTr("Not connected");
                            }
                            color: Bt.enabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Switch {
                        visible: Bt.available && !Bt.blocked

                        checked: Bt.enabled
                        onToggled: checked => Bt.setEnabled(checked)
                    }
                }
            }

            RowLayout {
                visible: Bt.enabled

                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.medium
                Layout.topMargin: Appearance.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true

                    animate: true
                    text: Bt.devices.length === 1 ? qsTr("1 device") : qsTr("%1 devices").arg(Bt.devices.length)
                    color: Appearance.palette.m3onSurfaceVariant
                }

                // Discovery is on for as long as the panel is open, so
                // this says it is looking rather than offering to.
                MaterialSymbol {
                    visible: Bt.discovering

                    icon: "progress_activity"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSurfaceVariant

                    RotationAnimation on rotation {
                        running: root.open && Bt.discovering
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
            }

            ColumnLayout {
                visible: Bt.enabled

                Layout.fillWidth: true
                spacing: Appearance.spacing.extraSmall

                Repeater {
                    // The module's own objects, so a re-sort moves the
                    // rows rather than rebuilding them.
                    model: ScriptModel {
                        values: Bt.devices.slice(0, root.maxDevices)
                    }

                    DeviceItem {}
                }
            }
        }
    }
}
