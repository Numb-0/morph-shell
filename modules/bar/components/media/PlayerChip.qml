import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services.session

// One player in the panel's picker: its app icon and name on a tonal
// chip, filled while it is the one the panel shows, with a pin while
// it is held there rather than chosen for being the one playing.
Rectangle {
    id: chip

    required property var modelData

    readonly property bool current: Players.active === modelData
    readonly property bool pinned: Players.chosen === modelData

    readonly property string iconPath: Players.icon(modelData)
    readonly property color tint: current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

    implicitWidth: chipRow.implicitWidth + Appearance.padding.medium * 2
    implicitHeight: 32

    radius: height / 2
    color: current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: chipHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Players.choose(chip.modelData)
    }

    Rectangle {
        anchors.fill: parent

        radius: parent.radius
        color: Colours.palette.m3onSurface
        opacity: chipHover.hovered ? 0.08 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    Row {
        id: chipRow

        anchors.centerIn: parent
        spacing: Appearance.spacing.extraSmall

        IconImage {
            anchors.verticalCenter: parent.verticalCenter

            visible: chip.iconPath !== ""
            implicitSize: Appearance.font.icon.small
            source: chip.iconPath
        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            visible: chip.iconPath === ""
            icon: chip.modelData.isPlaying ? "graphic_eq" : "music_note"
            size: Appearance.font.icon.small
            color: chip.tint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            text: chip.modelData.identity || qsTr("Player")
            color: chip.tint
            font.weight: Font.Medium
        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            visible: chip.pinned
            icon: "keep"
            size: Appearance.font.icon.small
            color: chip.tint
            fill: 1
        }
    }
}
