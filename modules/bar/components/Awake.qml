import QtQuick
import qs.components
import qs.config
import qs.services.session

// Bar widget: a cup that keeps the session up. A click fills it, and
// until it is clicked again the screen never dims, locks or goes off on
// its own; empty, it idles as usual.
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
        onTapped: Idle.toggleAwake()
    }

    MaterialSymbol {
        id: icon

        anchors.centerIn: parent

        icon: "coffee"
        size: Appearance.font.icon.normal

        color: Idle.awake ? Appearance.palette.m3primary : Appearance.palette.m3onSurfaceVariant
        fill: Idle.awake || root.hovered ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on color {
            CAnim {}
        }

        // The same pop the profile gives, so a click lands as something
        // having happened before the fill has finished.
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
            target: Idle

            function onAwakeChanged(): void {
                pop.restart();
            }
        }
    }
}
