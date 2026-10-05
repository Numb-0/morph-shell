import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config

// One application in the launcher's results: its icon, its name, and
// what it says it is.
Item {
    id: root

    required property int index
    required property DesktopEntry modelData

    // The pointer came onto the row, which selects it, so the pointer
    // and the arrows never disagree about what Enter would run.
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
        anchors.leftMargin: Appearance.padding.medium
        anchors.rightMargin: Appearance.padding.medium
        spacing: Appearance.spacing.medium

        IconImage {
            anchors.verticalCenter: parent.verticalCenter

            implicitSize: Appearance.font.icon.large
            source: Quickshell.iconPath(root.modelData.icon, "application-x-executable")
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            width: parent.width - Appearance.font.icon.large - parent.spacing

            StyledText {
                width: parent.width

                text: root.modelData.name
                font.pixelSize: Appearance.font.normal
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width

                // Whatever the app says it is, when it says anything.
                // The row keeps its height either way, so a list of
                // mixed entries does not jitter.
                visible: text.length > 0
                text: root.modelData.genericName || root.modelData.comment || ""
                color: Appearance.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
