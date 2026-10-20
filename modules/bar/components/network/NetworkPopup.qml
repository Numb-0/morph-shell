import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.config
import qs.services.system

// The network panel: the Wi-Fi switch, the wired link if there is one,
// and the networks in range to join or leave.
//
// Laid out as caelestia's network popout is -- a switch, a count, the
// list -- but with the password asked for in place, under the
// network that wants it, rather than in a second popout: the panel just
// grows to take the field.
BlobPopup {
    id: root

    // A bound on the rows built, not on what is shown: the list scrolls
    // past visibleRows. Anything further down is too weak to join.
    readonly property int maxNetworks: 30

    // How many rows the list shows before it scrolls, so the panel does
    // not run down the screen in a crowded building.
    readonly property int visibleRows: 7
    readonly property int rowHeight: 44

    readonly property int panelWidth: 300

    // The scanner runs while the panel is open, so the list is what is
    // in range now. The field goes with the panel, too, so it is not
    // waiting there next time.
    onOpenChanged: {
        Net.watch(open);
        if (!open)
            Net.cancelPassword();
    }

    Component.onDestruction: if (open)
        Net.watch(false)

    // Boxed at a fixed width rather than sized to the column, which
    // would stretch to fit the longest SSID in range.
    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            // The switch sits on its own tonal card, as the top of an M3
            // quick-settings sheet does.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56

                radius: Appearance.rounding.extraLarge
                color: Net.wifiEnabled ? Appearance.palette.m3primaryContainer : Appearance.palette.m3surfaceContainerHigh

                Behavior on color {
                    CAnim {}
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.medium
                    spacing: Appearance.spacing.medium

                    MaterialSymbol {
                        icon: Net.wifiEnabled ? "wifi" : "wifi_off"
                        size: Appearance.font.icon.normal
                        color: Net.wifiEnabled ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurfaceVariant
                        fill: Net.wifiEnabled ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: qsTr("Wi-Fi")
                            font.pixelSize: Appearance.font.normal
                            font.weight: Font.Medium
                            color: Net.wifiEnabled ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true

                            animate: true
                            text: !Net.wifi ? qsTr("No adapter") : Net.wifiBlocked ? qsTr("Blocked by hardware switch") : !Net.wifiEnabled ? qsTr("Off") : Net.active?.name ?? qsTr("Not connected")
                            color: Net.wifiEnabled ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Switch {
                        visible: Net.wifi !== null && !Net.wifiBlocked

                        checked: Net.wifiEnabled
                        onToggled: checked => Net.setWifiEnabled(checked)
                    }
                }
            }

            // The wired link, when there is one. Nothing to do with it from
            // here, so it is a line of status rather than a control.
            RowLayout {
                visible: Net.ethernet !== null

                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.large
                Layout.topMargin: Appearance.spacing.extraSmall
                spacing: Appearance.spacing.medium

                MaterialSymbol {
                    icon: "lan"
                    color: Appearance.palette.m3primary
                    fill: 1
                }

                StyledText {
                    Layout.fillWidth: true

                    text: qsTr("Ethernet")
                    font.pixelSize: Appearance.font.normal
                }

                StyledText {
                    text: Net.ethernet?.name ?? ""
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                visible: Net.wifiEnabled && Net.wifi !== null

                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.medium
                Layout.topMargin: Appearance.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true

                    animate: true
                    text: Net.networks.length === 1 ? qsTr("1 network available") : qsTr("%1 networks available").arg(Net.networks.length)
                    color: Appearance.palette.m3onSurfaceVariant
                }

                // The scanner is on for as long as the panel is open
                // and rescans by itself, so this says it is looking
                // rather than offering to look again.
                MaterialSymbol {
                    icon: "progress_activity"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSurfaceVariant

                    RotationAnimation on rotation {
                        running: root.open
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
            }

            // A Flickable over the rows rather than a ListView: a ListView
            // destroys rows scrolled out of view, and a half typed
            // password with them.
            Flickable {
                id: list

                function reveal(row: Item): void {
                    contentY = Math.max(Math.min(contentY, row.y), row.y + row.height - height);
                }

                visible: Net.wifiEnabled

                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, root.visibleRows * root.rowHeight + (root.visibleRows - 1) * rows.spacing)

                contentWidth: width
                contentHeight: rows.implicitHeight

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: rows

                    width: list.width
                    spacing: Appearance.spacing.extraSmall

                    Repeater {
                        // The networks are the module's own objects, so a
                        // re-sort moves the rows it already has rather than
                        // rebuilding them, and a half typed password is not
                        // thrown away with its row.
                        model: ScriptModel {
                            values: Net.networks.slice(0, root.maxNetworks)
                        }

                        NetworkItem {
                            id: networkItem

                            rowHeight: root.rowHeight
                            onRevealRequested: list.reveal(networkItem)
                        }
                    }
                }
            }

        }
    }
}
