pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config

// A tray item's menu, as an M3 menu grown out of the bar rather than the
// application's own toolkit menu. The entries come from the application
// over D-Bus and can arrive or change after the panel has opened; the
// panel follows them in size.
//
// A submenu replaces the list it came from, with a row at the top to go
// back, rather than opening beside it: a panel fused to the bar has
// nowhere beside it to open into.
BlobPopup {
    id: root

    // Whose menu this is. Set by the bar before it opens the panel.
    property SystemTrayItem item: null

    // Asks the bar to close the panel: once an action has been picked,
    // or on Escape from the top of the menu.
    signal finished

    // The submenus walked into, from the top: the one shown is the last.
    property list<var> trail: []

    readonly property var shown: trail.length > 0 ? trail[trail.length - 1] : item?.menu ?? null

    // An application can still rebuild its menu while it is open, which
    // destroys the submenu being shown out from under the walk. Back to
    // the top then, rather than onto an empty list.
    onShownChanged: if (trail.length > 0 && !shown)
        trail = []

    // A fresh walk each time it opens, or when it moves to another item.
    onOpenChanged: if (open) {
        trail = [];
        keys.forceActiveFocus();
    }
    onItemChanged: trail = []

    function enter(entry: var): void {
        trail = [...trail, entry];
    }

    function back(): void {
        trail = trail.slice(0, -1);
    }

    // The click goes out over D-Bus; closing on the spot can tear the
    // menu down before the application has had it.
    function pick(entry: var): void {
        entry.triggered();
        closing.restart();
    }

    // Kept for the entries: only reserve a column for check marks or
    // icons when some entry in this list has one, so the labels of a
    // plain menu start at the edge and those of a mixed one line up.
    readonly property var entries: opener.children.values
    readonly property bool hasChecks: entries.some(e => !e.isSeparator && e.buttonType !== QsMenuButtonType.None)
    readonly property bool hasIcons: entries.some(e => !e.isSeparator && e.icon !== "")

    // One menu row. M3's menu item: a state layer over the whole row, the
    // leading check or icon, the label, and a chevron for a submenu.
    component Entry: Item {
        id: entry

        required property var modelData

        readonly property bool usable: modelData.enabled

        Layout.fillWidth: true
        implicitWidth: rowLayout.implicitWidth + Appearance.padding.medium * 2
        implicitHeight: modelData.isSeparator ? Appearance.spacing.small * 2 + 1 : 40

        // A hairline across the menu, as M3 divides groups of items.
        Rectangle {
            visible: entry.modelData.isSeparator

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right

            height: 1
            color: Appearance.palette.m3outlineVariant
        }

        HoverHandler {
            id: entryHover

            enabled: !entry.modelData.isSeparator && entry.usable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: entryTap

            enabled: !entry.modelData.isSeparator && entry.usable

            onTapped: entry.modelData.hasChildren ? root.enter(entry.modelData) : root.pick(entry.modelData)
        }

        Rectangle {
            visible: !entry.modelData.isSeparator

            anchors.fill: parent

            radius: Appearance.rounding.medium
            color: Appearance.palette.m3onSurface
            opacity: entryTap.pressed ? 0.12 : entryHover.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        RowLayout {
            id: rowLayout

            visible: !entry.modelData.isSeparator

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.medium
            anchors.rightMargin: Appearance.padding.medium
            spacing: Appearance.spacing.medium

            // M3 draws a disabled item at 38% of its colour.
            opacity: entry.usable ? 1 : 0.38

            MaterialSymbol {
                visible: root.hasChecks

                readonly property int kind: entry.modelData.buttonType
                readonly property int checked: entry.modelData.checkState

                icon: {
                    if (kind === QsMenuButtonType.RadioButton)
                        return checked === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked";
                    if (kind === QsMenuButtonType.CheckBox)
                        return checked === Qt.Checked ? "check_box" : checked === Qt.PartiallyChecked ? "indeterminate_check_box" : "check_box_outline_blank";
                    return "";
                }
                size: Appearance.font.icon.small
                color: checked !== Qt.Unchecked ? Appearance.palette.m3primary : Appearance.palette.m3onSurfaceVariant
                fill: checked !== Qt.Unchecked ? 1 : 0
            }

            Item {
                visible: root.hasIcons

                implicitWidth: Appearance.font.icon.small
                implicitHeight: Appearance.font.icon.small

                IconImage {
                    anchors.fill: parent

                    visible: entry.modelData.icon !== ""
                    source: entry.modelData.icon
                }
            }

            StyledText {
                Layout.fillWidth: true

                text: entry.modelData.text
                font.pixelSize: Appearance.font.normal
                elide: Text.ElideRight
            }

            MaterialSymbol {
                visible: entry.modelData.hasChildren

                icon: "chevron_right"
                size: Appearance.font.icon.small
                color: Appearance.palette.m3onSurfaceVariant
            }
        }
    }

    Item {
        id: keys

        anchors.centerIn: parent

        // As wide as the widest entry wants, within reason: an M3 menu
        // runs 112 to 280dp.
        implicitWidth: Math.max(200, Math.min(300, column.implicitWidth))
        implicitHeight: column.implicitHeight

        focus: true

        // Kept in here rather than on the popup: the popup takes one
        // item as its content, and nothing else.
        Timer {
            id: closing

            interval: 80
            onTriggered: root.finished()
        }

        QsMenuOpener {
            id: opener

            menu: root.shown
        }

        // Holds on to every menu between the top and the one shown. A
        // menu nobody holds counts as closed, and some applications
        // rebuild theirs when it is reopened -- which would destroy the
        // very submenu just walked into.
        Instantiator {
            model: [root.item?.menu, ...root.trail.slice(0, -1)].filter(m => m)

            delegate: QsMenuOpener {
                required property var modelData

                menu: modelData
            }
        }

        // Escape backs out of a submenu, then closes the menu.
        Keys.onEscapePressed: root.trail.length > 0 ? root.back() : root.finished()

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            // Whose menu it is, or, inside a submenu, the way back out.
            Item {
                id: heading

                Layout.fillWidth: true
                implicitWidth: header.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: 40

                readonly property bool inSubmenu: root.trail.length > 0

                HoverHandler {
                    id: headerHover

                    enabled: heading.inSubmenu
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: headerTap

                    enabled: heading.inSubmenu

                    onTapped: root.back()
                }

                Rectangle {
                    anchors.fill: parent

                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3onSurface
                    visible: heading.inSubmenu
                    opacity: headerTap.pressed ? 0.12 : headerHover.hovered ? 0.08 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                RowLayout {
                    id: header

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.medium
                    anchors.rightMargin: Appearance.padding.medium
                    spacing: Appearance.spacing.medium

                    MaterialSymbol {
                        visible: heading.inSubmenu

                        icon: "arrow_back"
                        size: Appearance.font.icon.small
                        color: Appearance.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true

                        animate: true
                        text: heading.inSubmenu ? root.trail[root.trail.length - 1].text : root.item?.tooltipTitle || root.item?.title || root.item?.id || ""
                        font.pixelSize: Appearance.font.normal
                        font.weight: Font.Medium
                        color: heading.inSubmenu ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.extraSmall
                Layout.bottomMargin: Appearance.spacing.extraSmall
                implicitHeight: 1

                color: Appearance.palette.m3outlineVariant
            }

            // The entries, sliding in from the side they were reached
            // from: forwards into a submenu from the right, back out from
            // the left.
            ColumnLayout {
                id: list

                Layout.fillWidth: true
                spacing: 0

                property int depth: root.trail.length
                property int lastDepth: 0

                onDepthChanged: {
                    slide.from = depth > lastDepth ? 24 : -24;
                    lastDepth = depth;
                    arrive.restart();
                }

                transform: Translate {
                    id: slide

                    property real from: 0
                }

                ParallelAnimation {
                    id: arrive

                    Anim {
                        target: slide
                        property: "x"
                        from: slide.from
                        to: 0
                        type: Anim.DefaultSpatial
                    }

                    Anim {
                        target: list
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.DefaultEffects
                    }
                }

                Repeater {
                    model: opener.children

                    Entry {}
                }
            }
        }
    }
}
