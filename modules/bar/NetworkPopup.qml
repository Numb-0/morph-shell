import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.config
import qs.services

// The network panel: the Wi-Fi switch, the wired link if there is one,
// and the networks in range to join or leave.
//
// Laid out as caelestia's network popout is -- a switch, a count, the
// list -- but with the password asked for in place, under the
// network that wants it, rather than in a second popout: the panel just
// grows to take the field.
BlobPopup {
    id: root

    // Enough to pick from without the panel running down the screen;
    // the rest are almost always too weak to join anyway.
    readonly property int maxNetworks: 7

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

    // One network in range, and its password field when it asks for one.
    component NetworkItem: ColumnLayout {
        id: item

        required property var modelData

        readonly property bool active: modelData.connected
        readonly property bool connecting: modelData.state === ConnectionState.Connecting
        readonly property bool askingPassword: Net.passwordNetwork === modelData

        Layout.fillWidth: true
        spacing: Appearance.spacing.extraSmall

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44

            // The joined network sits on a tonal pill, as a selected
            // list item does in M3; the rest only light up under the
            // pointer.
            radius: height / 2
            color: item.active ? Appearance.palette.m3secondaryContainer : itemHover.hovered ? Qt.alpha(Appearance.palette.m3onSurface, 0.08) : "transparent"

            Behavior on color {
                CAnim {}
            }

            HoverHandler {
                id: itemHover

                cursorShape: item.active ? Qt.ArrowCursor : Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: if (!item.active)
                    Net.connectTo(item.modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.medium
                anchors.rightMargin: Appearance.padding.extraSmall
                spacing: Appearance.spacing.medium

                MaterialSymbol {
                    icon: Net.strengthIcon(item.modelData.signalStrength)
                    color: item.active ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
                    fill: 1
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

                        // Only for the one joined or being joined, and the
                        // ones joined before, so the list stays a list of
                        // names rather than of fine print.
                        visible: text !== ""

                        animate: true
                        text: item.connecting ? qsTr("Connecting…") : item.active ? qsTr("Connected") : item.modelData.known ? qsTr("Saved") : ""
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }

                MaterialSymbol {
                    visible: Net.isSecure(item.modelData)

                    icon: "lock"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSurfaceVariant
                }

                // Leave, for the joined one; a spinner while joining;
                // nothing otherwise, since the whole row is the button.
                Item {
                    implicitWidth: 32
                    implicitHeight: 32

                    IconButton {
                        anchors.fill: parent

                        visible: item.active

                        icon: "link_off"
                        color: Appearance.palette.m3primary

                        onActivated: Net.disconnectWifi()
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent

                        visible: item.connecting

                        icon: "progress_activity"
                        size: Appearance.font.icon.small
                        color: Appearance.palette.m3primary

                        RotationAnimation on rotation {
                            running: item.connecting
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }
                }
            }
        }

        // An M3 outlined field: the outline takes the primary colour
        // while focused, as the label above it would.
        Rectangle {
            id: field

            visible: item.askingPassword

            Layout.fillWidth: true
            implicitHeight: 44

            radius: height / 2
            color: Appearance.palette.m3surfaceContainerHighest
            border.width: 2
            border.color: password.activeFocus ? Appearance.palette.m3primary : Appearance.palette.m3outline

            Behavior on border.color {
                CAnim {}
            }

            // Fresh each time it opens, and holding the keyboard, so the
            // password can be typed straight away.
            onVisibleChanged: {
                password.text = "";
                password.echoMode = TextInput.Password;
                if (visible)
                    password.forceActiveFocus();
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.extraSmall
                spacing: Appearance.spacing.small

                TextInput {
                    id: password

                    Layout.fillWidth: true

                    color: Appearance.palette.m3onSurface
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.normal

                    renderType: TextInput.NativeRendering
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    selectByMouse: true
                    selectionColor: Appearance.palette.m3primary
                    selectedTextColor: Appearance.palette.m3onPrimary
                    clip: true

                    Keys.onReturnPressed: Net.connectWithPassword(item.modelData, text)
                    Keys.onEnterPressed: Net.connectWithPassword(item.modelData, text)
                    Keys.onEscapePressed: Net.cancelPassword()

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: password.text.length === 0

                        text: qsTr("Password")
                        font.pixelSize: Appearance.font.normal
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }

                IconButton {
                    icon: password.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                    color: Appearance.palette.m3onSurfaceVariant

                    onActivated: password.echoMode = password.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
                }

                IconButton {
                    icon: "arrow_forward"
                    color: Appearance.palette.m3primary

                    onActivated: Net.connectWithPassword(item.modelData, password.text)
                }
            }
        }
    }

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
                        color: Net.wifiEnabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                        fill: Net.wifiEnabled ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: qsTr("Wi-Fi")
                            font.pixelSize: Appearance.font.normal
                            font.weight: Font.Medium
                            color: Net.wifiEnabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true

                            animate: true
                            text: !Net.wifi ? qsTr("No adapter") : Net.wifiBlocked ? qsTr("Blocked by hardware switch") : !Net.wifiEnabled ? qsTr("Off") : Net.active?.name ?? qsTr("Not connected")
                            color: Net.wifiEnabled ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
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

            ColumnLayout {
                visible: Net.wifiEnabled

                Layout.fillWidth: true
                spacing: Appearance.spacing.extraSmall

                Repeater {
                    // The networks are the module's own objects, so a
                    // re-sort moves the rows it already has rather than
                    // rebuilding them, and a half typed password is not
                    // thrown away with its row.
                    model: ScriptModel {
                        values: Net.networks.slice(0, root.maxNetworks)
                    }

                    NetworkItem {}
                }
            }

            StyledText {
                visible: Net.error !== ""

                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.large

                text: Net.error
                color: Appearance.palette.m3error
                wrapMode: Text.Wrap
            }
        }
    }
}
