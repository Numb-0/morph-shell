import QtQuick
import qs.config

// A push pin that holds something open -- the bar, the dock. Unpinned it
// lies tilted and hollow; pinned it stands upright, filled, as if pushed
// in. It only shows the state and asks for it to flip: whoever places it
// owns what pinned means.
Item {
    id: root

    required property bool pinned

    property int size: Appearance.font.icon.normal
    property real horizontalPadding: Appearance.padding.small

    readonly property bool hovered: hover.hovered

    signal toggled

    // Pushed in: a quick press on every change, however it came about.
    onPinnedChanged: glyph.press()

    implicitWidth: glyph.implicitWidth + horizontalPadding * 2
    implicitHeight: glyph.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.toggled()
    }

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: "keep"
        size: root.size
        color: root.pinned ? Appearance.palette.m3primary : root.hovered ? Appearance.palette.m3onSurface : Appearance.palette.m3onSurfaceVariant
        fill: root.pinned ? 1 : 0
        rotation: root.pinned ? 0 : 45

        Behavior on fill {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on rotation {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }
}
