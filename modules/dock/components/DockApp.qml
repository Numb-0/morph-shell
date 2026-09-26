import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// One pinned application: its icon, whether it is running, and what a
// click on it does.
Item {
    id: root

    required property DesktopEntry entry

    readonly property bool hovered: hover.hovered

    // Reads the toplevel list, so it re-evaluates whenever a window
    // opens or closes rather than only when the dock is rebuilt.
    readonly property bool running: Apps.isRunning(entry)

    readonly property int size: Appearance.dock.iconSize

    implicitWidth: size + Appearance.padding.small * 2
    implicitHeight: size + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        // Raises the app's windows, or starts it if it has none.
        onTapped: Apps.activate(root.entry)
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        // A second copy on purpose, for the times raising the first one
        // is not what you meant.
        onTapped: Apps.launch(root.entry)
    }

    IconImage {
        id: icon

        anchors.centerIn: parent

        implicitSize: root.size

        // The theme's icon for the entry, falling back to the generic
        // executable rather than to an empty square when the app ships
        // no icon the theme knows.
        source: Quickshell.iconPath(root.entry.icon, "application-x-executable")

        // Lifts towards the pointer, the way a dock is expected to. The
        // spatial curve overshoots, so it lands rather than ramps.
        scale: hover.hovered ? 1.18 : 1
        y: hover.hovered ? -Appearance.spacing.extraSmall : 0

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on y {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    // The running mark. Sits under the icon rather than over it, and is
    // a dot rather than a bar so it reads at a glance without competing
    // with the icon it belongs to.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Appearance.padding.extraSmall / 2

        implicitWidth: root.running ? Appearance.padding.extraSmall : 0
        implicitHeight: implicitWidth

        radius: height / 2
        color: Appearance.palette.primary

        Behavior on implicitWidth {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }
}
