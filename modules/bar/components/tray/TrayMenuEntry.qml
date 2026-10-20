import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config

// One menu row. M3's menu item: a state layer over the whole row, the
// leading check or icon, the label, and a chevron for a submenu.
Item {
    id: entry

    required property var modelData

    // The TrayMenuPopup this row belongs to: it walks the menu and knows
    // whether any row has a check or an icon to leave room for.
    property var menu

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
        color: Colours.palette.m3outlineVariant
    }

    HoverHandler {
        id: entryHover

        enabled: !entry.modelData.isSeparator && entry.usable
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: entryTap

        enabled: !entry.modelData.isSeparator && entry.usable

        onTapped: entry.modelData.hasChildren ? entry.menu.enter(entry.modelData) : entry.menu.pick(entry.modelData)
    }

    Rectangle {
        visible: !entry.modelData.isSeparator

        anchors.fill: parent

        radius: Appearance.rounding.medium
        color: Colours.palette.m3onSurface
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
            visible: entry.menu.hasChecks

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
            color: checked !== Qt.Unchecked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fill: checked !== Qt.Unchecked ? 1 : 0
        }

        Item {
            visible: entry.menu.hasIcons

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
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
