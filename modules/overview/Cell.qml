import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config

// One workspace in the overview: the screen in miniature, over the
// wallpaper when there is one, with its number large and faint behind
// the windows. The free workspace past the ones in use shows a plus
// instead.
ClippingRectangle {
    id: root

    required property int wsId

    // The workspace this screen shows, and the one a dragged window would
    // drop into.
    property bool active: false
    property bool target: false

    // The free one, to go to or to drop a window into.
    property bool fresh: false

    signal entered
    signal picked

    radius: Appearance.rounding.large
    color: Appearance.palette.m3surfaceContainerLow

    border.width: active || target ? 2 : 0
    border.color: target ? Appearance.palette.m3tertiary : Appearance.palette.m3secondary

    Image {
        anchors.fill: parent

        visible: status === Image.Ready
        source: Appearance.wallpaper ? `file://${Appearance.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        asynchronous: true
        cache: true
        opacity: 0.55
    }

    // Lifts the cell a dragged window is over.
    Rectangle {
        anchors.fill: parent

        color: Appearance.palette.m3tertiary
        opacity: root.target ? 0.18 : area.containsMouse ? 0.08 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    Behavior on x {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on y {
        Anim {
            type: Anim.FastSpatial
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent

        visible: root.fresh
        icon: "add"
        size: Math.round(root.height * 0.36)
        color: Appearance.palette.m3onSurface
        opacity: 0.3
    }

    StyledText {
        anchors.centerIn: parent

        visible: !root.fresh
        text: root.wsId
        font.pixelSize: Math.round(root.height * 0.42)
        font.weight: Font.DemiBold
        color: root.active ? Appearance.palette.m3secondary : Appearance.palette.m3onSurface
        opacity: root.active ? 0.5 : 0.22
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.entered()
        onClicked: root.picked()
    }
}
