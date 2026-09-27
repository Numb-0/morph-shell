import QtQuick
import qs.components
import qs.config

// Bar widget: the power glyph at the very end of the bar, opening the
// session panel -- lock, restart, shut down -- on click.
Item {
    id: root

    signal clicked

    // Lit while its panel is open, so the glyph reads as the thing the
    // panel grew out of.
    property bool active: false

    readonly property bool hovered: hover.hovered

    implicitWidth: glyph.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: glyph.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: "power_settings_new"
        size: Appearance.font.icon.normal
        color: root.active || root.hovered ? Appearance.palette.error : Appearance.palette.text
    }
}
