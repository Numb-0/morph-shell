import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services.launcher

// One pinned application: its icon, whether it is running, and what a
// click on it does.
Item {
    id: root

    required property DesktopEntry entry

    readonly property bool hovered: hover.hovered

    // Reads the toplevel list, so it re-evaluates whenever a window
    // opens or closes rather than only when the dock is rebuilt.
    readonly property var windows: Apps.windowsFor(entry)
    readonly property bool running: windows.length > 0
    readonly property int windowCount: windows.length

    // Its windows are what the dock's chooser is showing, which holds
    // the icon up as if pointed at.
    property bool chosen: false

    // Two windows or more, a click asks the dock to lay them out to
    // pick from rather than guessing which one was meant.
    signal chooseRequested
    signal activated

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
        // Raises the app's window, starts it if it has none, or asks
        // which one when there are several.
        onTapped: {
            if (root.windowCount >= 2) {
                root.chooseRequested();
                return;
            }
            if (!root.running)
                root.launched();
            Apps.activate(root.entry);
            root.activated();
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
        scale: hover.hovered || root.chosen ? 1.18 : 1
        y: hover.hovered || root.chosen ? -Appearance.spacing.extraSmall : 0

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

    // The running marks: a dot for each window, up to a few, so how
    // many are open reads off the dock without opening anything. The
    // focused window's dot stretches into a pill. Under the icon rather
    // than over it, and measured from the icon's resting edge rather than
    // from the dock's, so they stay close to the icon instead of sinking
    // towards the border.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: root.size / 2 + Appearance.padding.extraSmall

        Repeater {
            model: Appearance.dock.maxDots

            // Each slot carries its share of the gap on either side, and
            // closes to nothing when its window is not there, so the dots
            // stay centred as they come and go.
            Item {
                id: slot

                required property int index

                readonly property bool shown: index < root.windowCount
                readonly property bool focused: shown && (root.windows[index]?.activated ?? false)
                readonly property real dot: Appearance.padding.extraSmall

                implicitWidth: shown ? mark.implicitWidth + dot : 0
                implicitHeight: dot

                Behavior on implicitWidth {
                    Anim {
                        type: Anim.Standard
                        duration: Appearance.anim.durations.fastSpatial
                    }
                }

                Rectangle {
                    id: mark

                    anchors.centerIn: parent

                    implicitWidth: !slot.shown ? 0 : slot.focused ? slot.dot * 2.5 : slot.dot
                    implicitHeight: slot.shown ? slot.dot : 0

                    radius: height / 2
                    color: Appearance.palette.m3primary

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.Standard
                            duration: Appearance.anim.durations.fastSpatial
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {
                            type: Anim.Standard
                            duration: Appearance.anim.durations.fastSpatial
                        }
                    }
                }
            }
        }
    }
}
