import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// The session panel: lock, restart and shut down, as a row of M3 tonal
// buttons. Everything about how it grows out of the bar lives in
// BlobPopup.
//
// Restart and shut down take a second press. The first arms the button
// -- it fills with the error colour and asks to be confirmed -- so a
// stray click on the way past cannot take the machine down.
BlobPopup {
    id: root

    // Asks the bar to close the panel once an action has been taken.
    signal finished

    // Which action is waiting on its confirming press, if any.
    property string armed: ""

    // Nothing stays armed across openings of the panel.
    onOpenChanged: if (!open)
        armed = ""

    function run(action: string, command: var, confirm: bool): void {
        if (confirm && armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }

        armed = "";
        root.finished();
        Quickshell.execDetached(command);
    }

    // A tonal icon button with its label under it. The container morphs
    // from a rounded square to a circle under the pointer, as M3
    // Expressive's shape-morphing buttons do.
    component ActionButton: ColumnLayout {
        id: btn

        required property string icon
        required property string label
        required property string action
        required property var command
        property bool confirm: false

        readonly property bool armed: root.armed === action
        readonly property bool hovered: btnHover.hovered

        spacing: Appearance.spacing.small

        Rectangle {
            id: container

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: 64
            implicitHeight: 64

            radius: btn.hovered || btn.armed ? height / 2 : Appearance.rounding.large
            color: btn.armed ? Appearance.palette.error : Qt.alpha(btn.confirm ? Appearance.palette.error : Appearance.palette.primary, 0.14)

            Behavior on radius {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on color {
                CAnim {}
            }

            // The M3 state layer: a wash of the content colour on hover,
            // a stronger one while pressed.
            Rectangle {
                anchors.fill: parent

                radius: parent.radius
                color: btn.armed ? Appearance.palette.background : Appearance.palette.text
                opacity: btnTap.pressed ? 0.16 : btn.hovered ? 0.08 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent

                icon: btn.icon
                size: Appearance.font.icon.large
                color: btn.armed ? Appearance.palette.background : btn.confirm ? Appearance.palette.error : Appearance.palette.primary
                fill: btn.hovered || btn.armed ? 1 : 0

                Behavior on fill {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            HoverHandler {
                id: btnHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: btnTap

                onTapped: root.run(btn.action, btn.command, btn.confirm)
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            animate: true
            text: btn.armed ? qsTr("Confirm") : btn.label
            font.pixelSize: Appearance.font.small
            color: btn.armed ? Appearance.palette.error : Appearance.palette.subtext
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.large

        // An armed button gives up on its own if it is not confirmed.
        // Held in here because the panel's default slot takes only the
        // one content item.
        Timer {
            id: disarm

            interval: 3000
            onTriggered: root.armed = ""
        }

        // Through logind, so whichever locker the session has wired to
        // lock requests -- hypridle's hyprlock, swayidle's swaylock --
        // is the one that comes up.
        ActionButton {
            icon: "lock"
            label: qsTr("Lock")
            action: "lock"
            command: ["loginctl", "lock-session"]
        }

        ActionButton {
            icon: "restart_alt"
            label: qsTr("Restart")
            action: "reboot"
            command: ["systemctl", "reboot"]
            confirm: true
        }

        ActionButton {
            icon: "power_settings_new"
            label: qsTr("Shut down")
            action: "poweroff"
            command: ["systemctl", "poweroff"]
            confirm: true
        }
    }
}
