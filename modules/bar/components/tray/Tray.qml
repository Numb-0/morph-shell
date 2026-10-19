pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config

// Bar widget: the system tray. One icon per application that has put
// itself there, leaving out the ones that say they have nothing to show
// right now. A left click is the application's own action -- or its menu,
// for those that only have a menu -- a middle click its second action,
// the wheel is passed on, and a right click opens its menu in a panel
// out of the bar (see TrayMenuPopup).
Item {
    id: root

    // Asks the bar to open or close an item's menu, under the icon that
    // asked.
    signal menuRequested(SystemTrayItem item, Item icon)

    // The item whose menu is open, lit as the other widgets are while
    // their panel is.
    property SystemTrayItem activeItem: null

    // How many icons the pointer is on. A count, since the icons come
    // out of a Repeater and a child handler takes the hover for itself
    // (see the bar's pointerInside).
    property int hoveredIcons: 0
    readonly property bool hovered: hover.hovered || hoveredIcons > 0

    // Where the icons start, for placing a menu under one of them.
    readonly property real rowX: row.x

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)

    visible: items.length > 0

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: Appearance.font.icon.normal + Appearance.padding.small * 2

    // Many applications hand over their icon as a theme name with the
    // directory it lives in tacked on, which the icon provider cannot
    // resolve. Split it: the theme's copy if it has one, else the file in
    // that directory.
    function iconSource(icon: string): string {
        if (!icon.includes("?path="))
            return icon;
        const [name, path] = icon.split("?path=");
        const file = name.slice(name.lastIndexOf("/") + 1);
        return Quickshell.iconPath(file, true) || `file://${path}/${file}`;
    }

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Repeater {
            model: ScriptModel {
                values: root.items
            }

            Item {
                id: icon

                required property SystemTrayItem modelData

                readonly property bool active: root.activeItem === modelData

                implicitWidth: Appearance.font.icon.normal
                implicitHeight: Appearance.font.icon.normal

                HoverHandler {
                    id: iconHover

                    cursorShape: Qt.PointingHandCursor

                    onHoveredChanged: root.hoveredIcons += hovered ? 1 : -1
                }

                Component.onDestruction: if (iconHover.hovered)
                    root.hoveredIcons--

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onTapped: (point, button) => {
                        press.restart();
                        const item = icon.modelData;
                        if (button === Qt.MiddleButton)
                            item.secondaryActivate();
                        else if (button === Qt.RightButton || item.onlyMenu)
                            item.hasMenu ? root.menuRequested(item, icon) : item.activate();
                        else
                            item.activate();
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y);
                        icon.modelData.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
                    }
                }

                IconImage {
                    id: image

                    anchors.centerIn: parent

                    implicitSize: parent.width
                    source: root.iconSource(icon.modelData.icon)

                    // Lifts a little under the pointer and while its menu
                    // is open, the way the dock's icons do.
                    scale: icon.active || iconHover.hovered ? 1.15 : 1

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    // The press, as the bar's glyphs have it. On its own
                    // transform, so it neither breaks the lift's binding
                    // nor gets smeared by its easing.
                    transform: Scale {
                        id: pressScale

                        origin.x: image.width / 2
                        origin.y: image.height / 2
                    }

                    SequentialAnimation {
                        id: press

                        ParallelAnimation {
                            Anim {
                                target: pressScale
                                property: "xScale"
                                to: 0.8
                                duration: 90
                                type: Anim.FastEffects
                            }
                            Anim {
                                target: pressScale
                                property: "yScale"
                                to: 0.8
                                duration: 90
                                type: Anim.FastEffects
                            }
                        }

                        ParallelAnimation {
                            Anim {
                                target: pressScale
                                property: "xScale"
                                to: 1
                                type: Anim.FastSpatial
                            }
                            Anim {
                                target: pressScale
                                property: "yScale"
                                to: 1
                                type: Anim.FastSpatial
                            }
                        }
                    }
                }

                // Says which icon the open menu belongs to.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 2

                    implicitWidth: icon.active ? 4 : 0
                    implicitHeight: implicitWidth
                    radius: height / 2
                    color: Appearance.palette.m3primary

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }
            }
        }
    }
}
