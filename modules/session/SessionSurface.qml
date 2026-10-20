pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services.session

// One screen of the session menu: the wallpaper, dimmed as the lock dims
// it, and on the menu's own screen the time in the top left, as the lock
// has it, over the row of buttons in the middle.
//
// Unlike the lock, the picture does not cut in: the desktop is still up
// under it, so it fades over it on the way in and back off it on the way
// out.
Item {
    id: root

    required property SessionMenu menu
    required property ShellScreen screen
    required property bool main

    // Up from the first frame, so the way in plays rather than starting
    // at its end.
    property bool shown: false
    Component.onCompleted: {
        shown = Qt.binding(() => root.menu.shown);
        if (main)
            content.forceActiveFocus();
    }

    // Sized from the screen rather than from this item, which only gets
    // its size once the window has been laid out: every size it passes
    // through on the way decodes the picture again, and with three
    // screens that was seven decodes holding up the opening. Decoded off
    // the main thread, so even the one does not stall the fade, and kept
    // in the cache, so opening again does not decode it at all. It fades
    // up once it is ready rather than popping in halfway.
    Image {
        id: wallpaper

        anchors.fill: parent

        source: Appearance.wallpaper ? `file://${Appearance.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true

        sourceSize.width: root.screen.width * (root.screen.devicePixelRatio || 1)
        sourceSize.height: root.screen.height * (root.screen.devicePixelRatio || 1)

        opacity: root.shown && status === Image.Ready ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // A touch darker than the lock's: the buttons want reading against
    // whatever the picture is.
    Rectangle {
        anchors.fill: parent

        color: {
            const c = Appearance.palette.m3scrim;
            return Qt.rgba(c.r, c.g, c.b, 0.4);
        }

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // A click anywhere off the buttons backs out, on any screen.
    MouseArea {
        anchors.fill: parent

        onClicked: root.menu.back()
    }

    Item {
        id: content

        anchors.fill: parent

        visible: root.main

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        focus: true
        Keys.onPressed: event => {
            event.accepted = true;
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                root.menu.select(root.menu.selected - 1);
                return;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                root.menu.select(root.menu.selected + 1);
                return;
            case Qt.Key_Home:
                root.menu.select(0);
                return;
            case Qt.Key_End:
                root.menu.select(root.menu.actions.length - 1);
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.menu.run(root.menu.selected);
                return;
            case Qt.Key_Escape:
                root.menu.back();
                return;
            }
            event.accepted = false;
        }

        Column {
            x: 200
            y: 200

            spacing: -Appearance.spacing.small

            StyledText {
                text: Time.format("HH:mm")
                font.pixelSize: 120
                color: Appearance.palette.m3primaryFixed
            }

            StyledText {
                leftPadding: Appearance.padding.small
                text: Time.format("dddd d MMMM")
                font.pixelSize: Appearance.font.large
                color: Appearance.palette.m3primaryFixedDim
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            anchors.verticalCenterOffset: 60

            spacing: Appearance.spacing.extraLarge

            Repeater {
                id: buttons

                model: root.menu.actions

                SessionButton {
                    required property var modelData
                    required property int index

                    menu: root.menu
                    action: modelData
                    position: index

                    // Where the chosen button sits relative to this one,
                    // for the others to draw in to when it is taken.
                    target: {
                        const chosen = buttons.itemAt(root.menu.selected);
                        return chosen ? chosen.x - x : 0;
                    }
                }
            }
        }

        // Says what the keys do, and on an armed button what is being
        // asked.
        StyledText {
            anchors.horizontalCenter: row.horizontalCenter
            anchors.top: row.bottom
            anchors.topMargin: Appearance.spacing.extraExtraLarge

            animate: true
            text: root.menu.armed !== "" ? qsTr("Press again to confirm  ·  Esc to cancel") : qsTr("←  →  to choose  ·  Enter to confirm  ·  Esc to close")
            font.pixelSize: Appearance.font.small
            color: root.menu.armed !== "" ? Appearance.palette.m3error : Appearance.palette.m3onSurfaceVariant

            opacity: root.menu.committing ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }
}
