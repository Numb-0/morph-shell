import QtQuick
import qs.components
import qs.config
import qs.services.launcher

// The calculator's answer at the head of the launcher's results: the
// answer large, and what was worked out under it. It reads both from
// the calculator rather than from its row, which stays the same while
// the answer changes under it.
Item {
    id: root

    // As an application row's: the pointer selects, a tap copies.
    signal pointed
    signal activated

    implicitHeight: Config.dock.resultHeight

    HoverHandler {
        cursorShape: Qt.PointingHandCursor

        onHoveredChanged: if (hovered)
            root.pointed()
    }

    TapHandler {
        onTapped: root.activated()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.small
        anchors.rightMargin: Appearance.padding.medium
        spacing: Appearance.spacing.medium

        // Primary rather than the commands' secondary, so the answer
        // stands out over the applications under it.
        Rectangle {
            id: badge

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: 36
            implicitHeight: 36

            radius: Appearance.rounding.medium
            color: Colours.palette.m3primaryContainer

            MaterialSymbol {
                anchors.centerIn: parent

                icon: "calculate"
                size: Appearance.font.icon.normal
                color: Colours.palette.m3onPrimaryContainer
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            width: parent.width - badge.width - copyIcon.width - parent.spacing * 2

            StyledText {
                width: parent.width

                text: Calc.result
                font.pixelSize: Appearance.font.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width

                text: Calc.expression
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        // Says what Enter does with it.
        MaterialSymbol {
            id: copyIcon

            anchors.verticalCenter: parent.verticalCenter

            icon: "content_copy"
            size: Appearance.font.icon.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
