import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services.launcher

// One application in the launcher's results: its icon, its name, what
// it says it is, and a pin to put it in the dock or take it out.
Item {
    id: root

    required property int index
    required property DesktopEntry modelData

    // The row the arrows are on, which shows its pin as the pointer
    // does.
    property bool selected: false

    // Waiting for its place in the dock, which keeps the pin up.
    property bool placing: false

    readonly property bool pinned: Apps.isPinned(modelData)

    // On the row or on its pin, whose own hover takes the pointer from
    // the row's.
    readonly property bool hovered: hover.hovered || pin.hovered

    // The pointer selects through the panel, which watches the whole
    // list; a tap runs.
    signal activated
    signal pinToggled

    width: ListView.view.width
    implicitHeight: Config.dock.resultHeight

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    // A tap on the pin reaches this one too, so it checks where the
    // tap landed: one on the pin is the pin's alone.
    TapHandler {
        onTapped: eventPoint => {
            if (!pin.contains(pin.mapFromItem(root, eventPoint.position)))
                root.activated();
        }
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

            width: parent.width - Appearance.font.icon.large - parent.spacing - pin.width - Appearance.spacing.small

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
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }

    // Shown on the row the pointer or the arrows are on, and always on
    // an app already pinned, so what is in the dock reads off the list.
    Pin {
        id: pin

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter

        pinned: root.pinned || root.placing
        size: Appearance.font.icon.normal

        // With the dock full, an app not in it has its pin greyed out
        // and dead, until another is taken out to make room.
        enabled: pinned || !Apps.pinsFull

        opacity: !(pinned || root.hovered || root.selected) ? 0 : enabled ? 1 : 0.38

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        onToggled: root.pinToggled()
    }
}
