import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The theme panel: every chromix theme as its wallpaper with a few of
// its colours laid over it, and a dark/light switch. Everything about
// how it grows out of the bar lives in BlobPopup.
BlobPopup {
    id: root

    // One theme: its wallpaper, three of its accents, and its name. The
    // previews follow the mode, so flipping to light shows what each
    // theme would look like in light.
    component Tile: ColumnLayout {
        id: tile

        required property var modelData

        readonly property string name: modelData.name
        readonly property string dir: Themes.dirFor(name)
        readonly property bool current: Themes.theme === name
        readonly property bool pending: Themes.busy && Themes.requested === name
        readonly property bool hovered: tileHover.hovered

        // Picked out as soon as it is clicked, rather than once chromix
        // has written it back.
        readonly property bool selected: Themes.requested !== "" ? Themes.requested === name : current

        // What the theme was rendered from, and the shell's own colours
        // out of it. Both files are written by chromix for every theme.
        property string wallpaper: ""
        property var colors: ({})

        spacing: Appearance.spacing.small

        FileView {
            path: tile.dir ? `${tile.dir}/chromix.json` : ""
            printErrors: false

            onLoaded: {
                try {
                    tile.wallpaper = JSON.parse(text()).source?.image ?? "";
                } catch (e) {
                    tile.wallpaper = "";
                }
            }
        }

        FileView {
            path: tile.dir ? `${tile.dir}/morph-shell/colors.json` : ""
            printErrors: false

            onLoaded: {
                try {
                    tile.colors = JSON.parse(text());
                } catch (e) {
                    tile.colors = {};
                }
            }
        }

        Item {
            Layout.preferredWidth: 144
            Layout.preferredHeight: 90

            ClippingRectangle {
                id: frame

                anchors.fill: parent

                radius: tile.selected ? Appearance.rounding.extraLarge : Appearance.rounding.medium
                color: tile.colors.surfaceContainerHighest ?? Appearance.palette.m3surfaceContainerHighest

                Behavior on radius {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Image {
                    anchors.fill: parent

                    source: tile.wallpaper ? `file://${tile.wallpaper}` : ""
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

                // The M3 state layer, and a slow pulse while chromix is
                // switching to this one.
                Rectangle {
                    anchors.fill: parent

                    color: Appearance.palette.m3onSurface
                    opacity: tileTap.pressed ? 0.16 : tile.hovered ? 0.08 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent

                    color: Appearance.palette.m3surface
                    visible: tile.pending

                    SequentialAnimation on opacity {
                        running: tile.pending
                        loops: Animation.Infinite

                        Anim {
                            from: 0
                            to: 0.4
                            type: Anim.SlowEffects
                        }
                        Anim {
                            to: 0
                            type: Anim.SlowEffects
                        }
                    }
                }

                // Primary, secondary and tertiary, overlapping in the
                // corner, each ringed in the theme's own surface so they
                // stand off whatever wallpaper is behind them.
                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.padding.small

                    spacing: -6

                    Repeater {
                        model: ["primary", "secondary", "tertiary"]

                        Rectangle {
                            required property string modelData

                            width: 18
                            height: 18
                            radius: 9

                            color: tile.colors[modelData] ?? "transparent"
                            border.width: 2
                            border.color: tile.colors.surface ?? Appearance.palette.m3surface
                            visible: tile.colors[modelData] !== undefined
                        }
                    }
                }
            }

            // Drawn over the frame rather than inside it, so the ring
            // is not clipped along with the wallpaper.
            Rectangle {
                anchors.fill: parent

                radius: frame.radius
                color: "transparent"
                border.width: 3
                border.color: Appearance.palette.m3primary
                opacity: tile.selected ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            HoverHandler {
                id: tileHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tileTap

                onTapped: Themes.set(tile.name)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.extraSmall

            MaterialSymbol {
                visible: tile.current

                icon: "check"
                size: Appearance.font.icon.small
                color: Appearance.palette.m3primary
            }

            StyledText {
                text: tile.name
                color: tile.selected ? Appearance.palette.m3primary : Appearance.palette.m3onSurfaceVariant
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true

                text: qsTr("Theme")
                font.pixelSize: Appearance.font.large
            }

            MaterialSymbol {
                icon: Themes.dark ? "dark_mode" : "light_mode"
                color: Appearance.palette.m3onSurfaceVariant
            }

            Switch {
                checked: Themes.dark

                onToggled: checked => Themes.setMode(checked ? "dark" : "light")
            }
        }

        GridLayout {
            columns: Math.min(3, Themes.themes.length)
            rowSpacing: Appearance.spacing.medium
            columnSpacing: Appearance.spacing.medium

            Repeater {
                model: Themes.themes

                Tile {}
            }
        }
    }
}
