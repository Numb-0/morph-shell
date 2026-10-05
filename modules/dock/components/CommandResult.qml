import QtQuick
import qs.components
import qs.config
import qs.services

// One of the shell's commands in the launcher's results: its name as
// it is typed, colon and all, so the list also teaches the spelling.
Item {
    id: root

    required property int index

    // A command, though for a frame while the launcher swaps rows over
    // it can still be the application the row before held -- hence the
    // fallbacks below.
    required property var modelData

    // As an application row's: the pointer selects, a tap runs.
    signal pointed
    signal activated

    width: ListView.view.width
    implicitHeight: Appearance.dock.resultHeight

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

        // Tonal, as the clipboard's text badge is, so a command reads
        // as the shell's own rather than as an app.
        Rectangle {
            id: badge

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: 36
            implicitHeight: 36

            radius: Appearance.rounding.medium
            color: Appearance.palette.m3secondaryContainer

            MaterialSymbol {
                anchors.centerIn: parent

                icon: root.modelData.icon ?? ""
                size: Appearance.font.icon.normal
                color: Appearance.palette.m3onSecondaryContainer
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            width: parent.width - badge.width - chevron.width - parent.spacing * 2

            StyledText {
                width: parent.width

                text: Commands.prefix + (root.modelData.name ?? "")
                font.pixelSize: Appearance.font.normal
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width

                text: root.modelData.description ?? ""
                color: Appearance.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        // Marks the commands that open another panel rather than doing
        // something and closing: there is more to come after this one.
        MaterialSymbol {
            id: chevron

            anchors.verticalCenter: parent.verticalCenter

            opacity: root.modelData.panel ? 1 : 0

            icon: "chevron_right"
            size: Appearance.font.icon.normal
            color: Appearance.palette.m3onSurfaceVariant
        }
    }
}
