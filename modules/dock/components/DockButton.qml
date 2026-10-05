import QtQuick
import qs.components
import qs.config

// A button in the dock's row that opens one of the panels it grows
// into -- the same thing that panel's keybind does. For now only the
// launcher has one: the clipboard is reached from inside it.
Item {
    id: root

    required property string icon

    // The panel it opens is the one the dock is showing.
    property bool active: false

    readonly property bool hovered: hover.hovered

    signal tapped

    implicitWidth: Appearance.dock.iconSize + Appearance.padding.small * 2
    implicitHeight: Appearance.dock.iconSize + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.tapped()
    }

    MaterialSymbol {
        anchors.centerIn: parent

        icon: root.icon
        size: Appearance.font.icon.large
        color: root.active || hover.hovered ? Appearance.palette.m3primary : Appearance.palette.m3onSurface

        // Fills while its panel is open, so the button shows the state
        // it put the dock in.
        fill: root.active ? 1 : 0
    }
}
