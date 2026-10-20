import QtQuick
import qs.config

// A round, borderless icon button with an M3 state layer.
Item {
    id: btn

    required property string icon
    property color color: Colours.palette.m3onSurface
    property int iconSize: Appearance.font.icon.small

    signal activated

    implicitWidth: 32
    implicitHeight: 32

    HoverHandler {
        id: btnHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: btn.activated()
    }

    Rectangle {
        anchors.fill: parent

        radius: width / 2
        color: btn.color
        opacity: btnHover.hovered ? 0.12 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent

        icon: btn.icon
        size: btn.iconSize
        color: btn.color
    }
}
