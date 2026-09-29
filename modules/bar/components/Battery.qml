import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the battery glyph and its charge, opening the battery
// panel on click exactly as the clock does.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    // Shared with the panel, which tints the same way. A tenth left is
    // an error, a fifth a warning, and charging is called out rather
    // than left to read as ordinary.
    readonly property color accent: Power.critical ? Appearance.palette.m3error : Power.low ? Appearance.palette.m3warning : Power.charging ? Appearance.palette.m3success : Appearance.palette.m3onSurface

    // The number is two digits for almost all of its life and three at
    // the top. Giving it a fixed box and hanging it off the right keeps
    // the bar still as it crosses, the same way the media widget's title
    // is boxed rather than sized to the track.
    readonly property int labelWidth: 36

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            glyph.press();
            root.clicked();
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0//Appearance.spacing.extraSmall

        MaterialSymbol {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter

            icon: Power.icon
            size: Appearance.font.icon.normal
            color: root.accent

            // Solid once the battery wants attention, outlined the rest
            // of the time -- so it reads before the colour does, and for
            // anyone the colour does not reach.
            fill: Power.low || Power.charging ? 1 : 0
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            width: root.labelWidth
            horizontalAlignment: Text.AlignRight

            text: Math.round(Power.percentage * 100) + "%"
            color: root.accent
        }
    }
}
