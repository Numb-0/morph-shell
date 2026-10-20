import QtQuick
import qs.components
import qs.config
import qs.services.session

// Bar widget: a palette glyph opening the theme window on click. A right
// click flips between dark and light without opening anything.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    implicitWidth: glyph.implicitWidth + Config.bar.itemPadding * 2
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
        color: root.hovered ? Colours.palette.m3primary : Colours.palette.m3onSurface
        fill: root.hovered ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.FastEffects
            }
        }
    }
}
