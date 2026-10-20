import QtQuick
import qs.components
import qs.config
import qs.services.session

// Bar widget: the weather's glyph, beside the clock. Click opens the
// weather panel. Named for what it shows rather than Weather, which
// would shadow the service of that name.
Item {
    id: root

    signal clicked

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

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: Weather.icon(Weather.current?.code ?? 0, Weather.current?.isDay ?? true)
        size: Appearance.font.icon.normal
        fill: 1
    }
}
