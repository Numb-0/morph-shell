import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: a push pin that holds the bar open. Unpinned it lies
// tilted and hollow; pinned it stands upright, filled, as if pushed in.
Item {
    id: root

    readonly property bool hovered: hover.hovered

    implicitWidth: glyph.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: glyph.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: BarState.togglePinned()
    }

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: "keep"
        size: Appearance.font.icon.normal
        color: BarState.pinned ? Appearance.palette.m3primary : root.hovered ? Appearance.palette.m3onSurface : Appearance.palette.m3onSurfaceVariant
        fill: BarState.pinned ? 1 : 0
        rotation: BarState.pinned ? 0 : 45

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

        // Pushed in: a quick press down and back on every pin.
        SequentialAnimation {
            id: press

            Anim {
                target: glyph
                property: "scale"
                to: 0.8
                type: Anim.FastEffects
            }
            Anim {
                target: glyph
                property: "scale"
                to: 1
                type: Anim.FastSpatial
            }
        }

        Connections {
            target: BarState

            function onPinnedChanged(): void {
                press.restart();
            }
        }
    }
}
