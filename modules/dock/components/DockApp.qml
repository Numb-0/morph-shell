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
    readonly property int windowCount: Apps.windowsFor(entry).length

    // Bouncing from the click that starts the app until one more of its
    // windows opens than there was at the click -- or until it gives up,
    // for the apps that never open one.
    property bool launching: false
    property int windowsAtLaunch: 0

    function launched(): void {
        windowsAtLaunch = windowCount;
        launching = true;
        launchTimeout.restart();
    }

    onWindowCountChanged: if (launching && windowCount > windowsAtLaunch)
        launching = false

    Timer {
        id: launchTimeout

        interval: 10000
        onTriggered: root.launching = false
    }

    readonly property int size: Appearance.dock.iconSize

    implicitWidth: size + Appearance.padding.small * 2
    implicitHeight: size + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        // Raises the app's windows, or starts it if it has none.
        onTapped: {
            if (!root.running)
                root.launched();
            Apps.activate(root.entry);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        // A second copy on purpose, for the times raising the first one
        // is not what you meant.
        onTapped: {
            root.launched();
            Apps.launch(root.entry);
        }
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
        // standard curve eases in without overshooting.
        scale: hover.hovered ? 1.18 : 1
        y: hover.hovered ? -Appearance.spacing.extraSmall : 0

        // How high the launch bounce has it, on top of the hover lift.
        // A transform rather than part of y, which eases every change and
        // would smear the bounce flat. Always lands before it stops, so
        // the icon never freezes in mid-air when the window arrives.
        property real bounce: 0

        transform: Translate {
            y: -icon.bounce
        }

        SequentialAnimation on bounce {
            running: root.launching
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: root.size / 3
                duration: 300
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                to: 0
                duration: 300
                easing.type: Easing.InQuad
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.Standard
                duration: Appearance.anim.durations.fastSpatial
            }
        }

        Behavior on y {
            Anim {
                type: Anim.Standard
                duration: Appearance.anim.durations.fastSpatial
            }
        }
    }

    // The running mark. Sits under the icon rather than over it, and is
    // a dot rather than a bar so it reads at a glance without competing
    // with the icon it belongs to. Measured from the icon's resting edge
    // rather than from the dock's, so it stays close to the icon instead
    // of sinking towards the border.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: root.size / 2 + Appearance.padding.extraSmall

        implicitWidth: root.running ? Appearance.padding.extraSmall : 0
        implicitHeight: implicitWidth

        radius: height / 2
        color: Appearance.palette.m3primary

        Behavior on implicitWidth {
            Anim {
                type: Anim.Standard
                duration: Appearance.anim.durations.fastSpatial
            }
        }
    }
}
