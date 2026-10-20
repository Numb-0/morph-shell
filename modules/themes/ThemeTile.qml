import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services.session

// One theme: its wallpaper with three of its accents laid over it, and
// its name below. Pointing at it previews it; a click selects it and a
// double click applies it straight away.
//
// The selection itself is not drawn here: it is the drop of primary the
// card moves behind the tiles, which shows round the selected one's
// edge as a ring.
Item {
    id: tile

    required property var modelData
    required property int index
    required property ThemePicker picker

    readonly property string name: modelData.name
    readonly property var info: picker.infoFor(name)
    readonly property var colors: info?.colors ?? ({})

    readonly property bool current: Themes.theme === name
    readonly property bool selected: picker.picked === name
    readonly property bool hovered: tileHover.hovered

    // The wallpaper's frame, which the card reads to place the drop and
    // to find where a double click's flood starts from.
    readonly property Item wallpaperFrame: frame

    // The card lays the tiles out on a fixed grid and sets their size;
    // the wallpaper takes this much of the height, the name the rest.
    property int frameHeight: 90

    signal applied

    Item {
        id: frameHolder

        width: parent.width
        height: tile.frameHeight

        ClippingRectangle {
            id: frame

            anchors.fill: parent

            radius: tile.selected ? Appearance.rounding.extraLarge : Appearance.rounding.medium
            color: tile.colors.surfaceContainerHighest ?? tile.picker.tones.m3surfaceContainerHighest

            Behavior on radius {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Image {
                anchors.fill: parent

                source: tile.info?.wallpaper ? `file://${tile.info.wallpaper}` : ""
                sourceSize.width: width * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            // The M3 state layer.
            Rectangle {
                anchors.fill: parent

                color: tile.picker.tones.m3onSurface
                opacity: tileTap.pressed ? 0.16 : tile.hovered ? 0.08 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            // Primary, secondary and tertiary, overlapping in the
            // corner, each ringed in the theme's own surface so they
            // stand off whatever wallpaper is behind them. They part a
            // little under the pointer, fanning the palette out.
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.small

                spacing: tile.hovered || tile.selected ? -2 : -6

                Behavior on spacing {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Repeater {
                    model: ["primary", "secondary", "tertiary"]

                    Rectangle {
                        required property string modelData

                        width: 18
                        height: 18
                        radius: 9

                        color: tile.colors[modelData] ?? "transparent"
                        border.width: 2
                        border.color: tile.colors.surface ?? tile.picker.tones.m3surface
                        visible: tile.colors[modelData] !== undefined
                    }
                }
            }
        }

        HoverHandler {
            id: tileHover

            cursorShape: Qt.PointingHandCursor

            onHoveredChanged: {
                if (hovered)
                    tile.picker.hovered = tile.name;
                else if (tile.picker.hovered === tile.name)
                    tile.picker.hovered = "";
            }
        }

        TapHandler {
            id: tileTap

            onTapped: tile.picker.picked = tile.name
            onDoubleTapped: {
                tile.picker.picked = tile.name;
                tile.applied();
            }
        }
    }

    Row {
        anchors.top: frameHolder.bottom
        anchors.topMargin: Appearance.spacing.small
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: Appearance.spacing.extraSmall

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            visible: tile.current

            icon: "check"
            size: Appearance.font.icon.small
            color: tile.picker.tones.m3primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            text: tile.picker.displayName(tile.name)
            color: tile.selected ? tile.picker.tones.m3primary : tile.picker.tones.m3onSurfaceVariant
            font.weight: tile.selected ? Font.Medium : Font.Normal
        }
    }
}
