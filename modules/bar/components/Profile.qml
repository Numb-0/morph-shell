import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the active power profile as a glyph. A click steps to the
// next profile and a right click to the one before, straight from the
// bar -- three states want no panel.
Item {
    id: root

    readonly property bool hovered: hover.hovered

    implicitWidth: icon.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onTapped: (point, button) => Profiles.cycle(button === Qt.RightButton ? -1 : 1)
    }

    MaterialSymbol {
        id: icon

        anchors.centerIn: parent

        icon: Profiles.icon
        size: Appearance.font.icon.normal

        // Performance held back by the daemon -- too hot, or on a lap --
        // reads as a warning rather than as the bolt it asked for.
        color: Profiles.degraded ? Appearance.palette.m3warning : Appearance.palette.m3primary
        fill: root.hovered ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.FastEffects
            }
        }

        // A small pop on every change, so a click lands as something
        // having happened even before the new glyph has been read.
        SequentialAnimation {
            id: pop

            Anim {
                target: icon
                property: "scale"
                to: 1.25
                type: Anim.FastEffects
            }
            Anim {
                target: icon
                property: "scale"
                to: 1
                type: Anim.Emphasized
            }
        }

        Connections {
            target: Profiles

            function onProfileChanged(): void {
                pop.restart();
            }
        }
    }
}
