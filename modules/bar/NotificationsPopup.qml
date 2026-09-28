pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.modules.notifications
import qs.services

// The notification centre: do not disturb, everything that has arrived
// and not been dismissed, and a way to clear it all.
//
// Each card can be swiped away either side. Clearing sweeps them off one
// after another from the top, rather than blanking the list at once.
BlobPopup {
    id: root

    // Set while the sweep runs, so every card sets off on its own delay.
    property bool clearing: false

    // Opening it is reading it. Anything landing while it is open has
    // been seen too.
    onOpenChanged: if (open)
        Notifs.markAllRead()

    function clearAll(): void {
        if (clearing || Notifs.list.length === 0)
            return;
        clearing = true;
        sweep.restart();
    }

    // A round, borderless icon button with an M3 state layer, as the
    // network panel's are.
    component IconButton: Item {
        id: btn

        required property string icon
        property color color: Appearance.palette.m3onSurface

        signal activated

        implicitWidth: 36
        implicitHeight: 36

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
            color: btn.color
        }
    }

    Item {
        anchors.centerIn: parent

        implicitWidth: Appearance.notifs.panelWidth
        implicitHeight: column.implicitHeight

        // Kept in here rather than on the popup: the popup takes one
        // item as its content, and nothing else.
        Connections {
            target: Notifs
            enabled: root.open

            function onUnreadChanged(): void {
                Notifs.markAllRead();
            }
        }

        // Long enough for the last card on screen to have gone.
        Timer {
            id: sweep

            interval: Math.min(Notifs.list.length, 10) * 45 + Appearance.anim.durations.standard

            onTriggered: {
                Notifs.clearAll();
                root.clearing = false;
            }
        }

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.small
                spacing: Appearance.spacing.small

                StyledText {
                    text: qsTr("Notifications")
                    font.pixelSize: Appearance.font.large
                    font.weight: Font.Medium
                }

                // How many, on a small tonal pill.
                Rectangle {
                    visible: Notifs.list.length > 0

                    implicitWidth: Math.max(implicitHeight, countLabel.implicitWidth + Appearance.padding.small * 2)
                    implicitHeight: 22
                    radius: height / 2
                    color: Appearance.palette.m3secondaryContainer

                    StyledText {
                        id: countLabel

                        anchors.centerIn: parent

                        animate: true
                        text: Notifs.list.length
                        color: Appearance.palette.m3onSecondaryContainer
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    visible: Notifs.list.length > 0

                    icon: "clear_all"
                    color: Appearance.palette.m3primary

                    onActivated: root.clearAll()
                }
            }

            // Do not disturb, on its own tonal card, as Wi-Fi is on the
            // network panel.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56

                radius: Appearance.rounding.extraLarge
                color: Notifs.dnd ? Appearance.palette.m3primaryContainer : Appearance.palette.m3surfaceContainerHigh

                Behavior on color {
                    CAnim {}
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.large
                    anchors.rightMargin: Appearance.padding.medium
                    spacing: Appearance.spacing.medium

                    MaterialSymbol {
                        icon: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        color: Notifs.dnd ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                        fill: Notifs.dnd ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: qsTr("Do not disturb")
                            font.pixelSize: Appearance.font.normal
                            font.weight: Font.Medium
                            color: Notifs.dnd ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true

                            animate: true
                            text: Notifs.dnd ? qsTr("Only critical ones pop up") : qsTr("Off")
                            color: Notifs.dnd ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Switch {
                        checked: Notifs.dnd
                        onToggled: checked => Notifs.dnd = checked
                    }
                }
            }

            // Nothing left: said plainly, with room, rather than an empty
            // panel. Both lines run the panel's full width and centre
            // their own text, so they sit in the middle whatever the
            // layout makes of them.
            ColumnLayout {
                visible: Notifs.list.length === 0

                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.extraLarge
                Layout.bottomMargin: Appearance.spacing.extraLarge
                spacing: Appearance.spacing.small

                MaterialSymbol {
                    Layout.fillWidth: true

                    icon: "notifications_paused"
                    size: 40
                    color: Appearance.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true

                    text: qsTr("All caught up")
                    font.pixelSize: Appearance.font.normal
                    color: Appearance.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ListView {
                id: list

                visible: Notifs.list.length > 0

                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, Appearance.notifs.panelHeight)

                clip: true
                spacing: Appearance.spacing.small
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                model: ScriptModel {
                    values: [...Notifs.list]
                }

                add: Transition {
                    ParallelAnimation {
                        Anim {
                            property: "opacity"
                            from: 0
                            to: 1
                            type: Anim.DefaultEffects
                        }

                        Anim {
                            property: "scale"
                            from: 0.85
                            to: 1
                            type: Anim.DefaultSpatial
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        Anim {
                            property: "opacity"
                            to: 0
                            type: Anim.FastEffects
                        }

                        Anim {
                            property: "scale"
                            to: 0.85
                            type: Anim.FastEffects
                        }
                    }
                }

                displaced: Transition {
                    Anim {
                        property: "y"
                        type: Anim.DefaultSpatial
                    }
                }

                delegate: Item {
                    id: card

                    required property var modelData
                    required property int index

                    property real dragX: 0
                    property bool leaving: false

                    width: ListView.view.width
                    implicitHeight: body.implicitHeight

                    // Off to whichever side it was pushed, then gone.
                    function throwAway(direction: int): void {
                        leaving = true;
                        dragX = direction * (width + 20);
                        disposal.restart();
                    }

                    Timer {
                        id: disposal

                        interval: Appearance.anim.durations.standard
                        onTriggered: card.modelData.dismiss()
                    }

                    // The sweep: off to the right, each a beat after the
                    // one above it. The model is cleared in one go at the
                    // end, so these only animate.
                    SequentialAnimation {
                        running: root.clearing

                        PauseAnimation {
                            duration: Math.min(card.index, 10) * 45
                        }

                        ScriptAction {
                            script: {
                                card.leaving = true;
                                card.dragX = card.width + 20;
                            }
                        }
                    }

                    Behavior on dragX {
                        enabled: !drag.active

                        Anim {
                            type: card.leaving ? Anim.Standard : Anim.FastSpatial
                        }
                    }

                    DragHandler {
                        id: drag

                        target: null
                        enabled: !card.leaving
                        yAxis.enabled: false

                        onActiveTranslationChanged: if (active)
                            card.dragX = activeTranslation.x

                        onActiveChanged: if (!active) {
                            if (Math.abs(card.dragX) > 100 || Math.abs(centroid.velocity.x) > 900)
                                card.throwAway(card.dragX < 0 ? -1 : 1);
                            else
                                card.dragX = 0;
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }

                    TapHandler {
                        enabled: card.modelData.hasDefault && !card.leaving

                        onTapped: card.modelData.invoke("default")
                    }

                    Rectangle {
                        id: body

                        x: card.dragX
                        width: card.width
                        implicitHeight: content.implicitHeight + Appearance.padding.medium * 2

                        opacity: 1 - Math.min(1, Math.abs(card.dragX) / card.width)
                        radius: Appearance.rounding.large
                        color: cardHover.hovered ? Appearance.palette.m3surfaceContainerHighest : Appearance.palette.m3surfaceContainerHigh

                        // A critical one keeps an accent edge, so it is
                        // still told apart once it has stopped popping up.
                        border.width: card.modelData.critical ? 1 : 0
                        border.color: Appearance.palette.m3error

                        Behavior on color {
                            CAnim {}
                        }

                        NotificationContent {
                            id: content

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Appearance.padding.medium

                            notif: card.modelData
                            bodyLines: 4
                            showClose: cardHover.hovered && !card.leaving

                            onCloseRequested: card.throwAway(1)
                        }
                    }
                }
            }
        }
    }
}
