import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: a palette glyph opening the theme panel on click. A right
// click flips between dark and light without opening anything.
Item {
    id: root

    signal clicked

    // Lit while its panel is open, as the session button is.
    property bool active: false

    readonly property bool hovered: hover.hovered

    implicitWidth: glyph.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: glyph.implicitHeight + Appearance.padding.small * 2

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

    TapHandler {
        acceptedButtons: Qt.RightButton

        onTapped: {
            glyph.press();
            Themes.toggleMode();
        }
    }

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: "palette"
        size: Appearance.font.icon.normal
        color: root.active || root.hovered ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
        fill: root.active || root.hovered ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.FastEffects
            }
        }
    }
}
