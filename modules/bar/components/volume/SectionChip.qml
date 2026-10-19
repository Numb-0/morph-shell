import QtQuick
import qs.components
import qs.config

// Opens one of the panel's folded sections: a tonal chip with a glyph,
// an optional count beside it, and a chevron that turns as it opens.
Rectangle {
    id: chip

    required property string icon
    property string label: ""
    property bool open: false

    signal toggled

    implicitWidth: chipRow.implicitWidth + Appearance.padding.medium * 2
    implicitHeight: 32

    radius: height / 2
    color: open ? Appearance.palette.m3secondaryContainer : Appearance.palette.m3surfaceContainerHigh

    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: chipHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: chip.toggled()
    }

    Rectangle {
        anchors.fill: parent

        radius: parent.radius
        color: Appearance.palette.m3onSurface
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

        readonly property color tint: chip.open ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            icon: chip.icon
            size: Appearance.font.icon.small
            color: chipRow.tint
            fill: chip.open ? 1 : 0
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: chip.label !== ""

            text: chip.label
            color: chipRow.tint
            font.weight: Font.Medium
        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            icon: "expand_more"
            size: Appearance.font.icon.small
            color: chipRow.tint
            rotation: chip.open ? 180 : 0

            Behavior on rotation {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }
    }
}
