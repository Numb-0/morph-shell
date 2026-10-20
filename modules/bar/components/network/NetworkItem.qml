import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.config
import qs.services.system

// One network in range, and its password field when it asks for one.
ColumnLayout {
    id: item

    required property var modelData

    // The popup's row height, so every row matches the list's sizing.
    property int rowHeight: 44

    // Asks the list to scroll this row into view.
    signal revealRequested

    readonly property bool active: modelData.connected
    readonly property bool connecting: modelData.state === ConnectionState.Connecting
    readonly property bool askingPassword: Net.passwordNetwork === modelData

    // What went wrong on this network, if the last thing to go wrong
    // did so here.
    readonly property string error: Net.errorNetwork === modelData ? Net.error : ""

    // A row near the bottom of the list would open its field out of
    // sight, so the list scrolls to it once the field has laid out.
    onAskingPasswordChanged: if (askingPassword)
        Qt.callLater(item.revealRequested)

    Layout.fillWidth: true
    spacing: Appearance.spacing.extraSmall

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: item.rowHeight

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

                    // Only for the one joined or being joined, one that
                    // just failed, and the ones joined before, so the
                    // list stays a list of names rather than of fine
                    // print.
                    visible: text !== ""

                    readonly property bool showsError: item.error !== "" && !item.connecting && !item.active

                    animate: true
                    text: item.connecting ? qsTr("Connecting…") : item.active ? qsTr("Connected") : showsError ? item.error : item.modelData.known && item.modelData !== Net.trial ? qsTr("Saved") : ""
                    color: showsError ? Appearance.palette.m3error : Appearance.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
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
        border.color: item.error !== "" ? Appearance.palette.m3error : password.activeFocus ? Appearance.palette.m3primary : Appearance.palette.m3outline

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
