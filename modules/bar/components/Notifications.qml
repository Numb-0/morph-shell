import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: a bell, and how many notifications are waiting. Click
// opens the notification centre, middle click toggles do not disturb.
// The bell rings -- swings on its hook -- whenever one arrives.
Item {
    id: root

    signal clicked

    // Lit while its panel is open, as the session button is.
    property bool active: false

    readonly property bool hovered: hover.hovered

    readonly property bool waiting: Notifs.unread > 0

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        onTapped: Notifs.toggleDnd()
    }

    Connections {
        target: Notifs

        function onArrived(): void {
            if (!Notifs.dnd)
                ring.restart();
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.extraSmall

        MaterialSymbol {
            id: bell

            anchors.verticalCenter: parent.verticalCenter

            icon: Notifs.dnd ? "notifications_off" : root.waiting ? "notifications_unread" : "notifications"
            size: Appearance.font.icon.normal
            color: root.active || root.waiting && !Notifs.dnd ? Appearance.palette.m3primary : Notifs.dnd ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
            fill: root.waiting || root.active ? 1 : 0

            // Swings from the top, where a bell hangs, rather than about
            // its middle.
            transform: Rotation {
                id: swing

                origin.x: bell.width / 2
                origin.y: 2
            }

            // A strike, then the swing dying away.
            SequentialAnimation {
                id: ring

                Anim {
                    target: swing
                    property: "angle"
                    to: 22
                    duration: 90
                    type: Anim.FastEffects
                }

                Anim {
                    target: swing
                    property: "angle"
                    to: -18
                    duration: 140
                    type: Anim.FastEffects
                }

                Anim {
                    target: swing
                    property: "angle"
                    to: 12
                    duration: 140
                    type: Anim.FastEffects
                }

                Anim {
                    target: swing
                    property: "angle"
                    to: -7
                    duration: 140
                    type: Anim.FastEffects
                }

                Anim {
                    target: swing
                    property: "angle"
                    to: 0
                    type: Anim.FastSpatial
                }
            }
        }

        // The count pops in and out rather than appearing, and takes its
        // room back from the bar as it goes.
        StyledText {
            id: count

            anchors.verticalCenter: parent.verticalCenter

            visible: scale > 0.01
            scale: root.waiting ? 1 : 0
            width: root.waiting ? implicitWidth : 0

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on width {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            text: Notifs.unread > 99 ? "99+" : Notifs.unread
            color: Notifs.dnd ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3primary
            font.weight: Font.Medium
        }
    }
}
