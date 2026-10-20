pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Morph.Blobs
import qs.components
import qs.config
import qs.services.session

// The theme window's card: the title and the light/dark choice, the
// preview, the theme's swatches, the tiles, and Cancel and Apply. All of
// it drawn in the palette of the theme being looked at.
Rectangle {
    id: root

    required property ThemePicker picker
    required property ShellScreen screen

    readonly property ThemePalette tones: picker.tones

    // A text button and a filled one, as M3 dialogs end on.
    component DialogButton: Rectangle {
        id: button

        required property ThemePalette tones
        required property string text
        property string icon: ""
        property bool filled: false

        signal activated

        // Disabled as M3 has it: onSurface at 38% for the content and 12%
        // for a filled button's container.
        function faded(c: color, a: real): color {
            return Qt.rgba(c.r, c.g, c.b, a);
        }

        readonly property color tint: !enabled ? faded(tones.m3onSurface, 0.38) : filled ? tones.m3onPrimary : tones.m3primary

        implicitWidth: buttonRow.implicitWidth + (filled ? Appearance.padding.large : Appearance.padding.medium) * 2
        implicitHeight: 40

        radius: height / 2
        color: !filled ? "transparent" : enabled ? tones.m3primary : faded(tones.m3onSurface, 0.12)

        Behavior on color {
            CAnim {}
        }

        HoverHandler {
            id: buttonHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: buttonTap

            onTapped: button.activated()
        }

        Rectangle {
            anchors.fill: parent

            radius: parent.radius
            color: button.filled ? button.tones.m3onPrimary : button.tones.m3primary
            opacity: !button.enabled ? 0 : buttonTap.pressed ? 0.12 : buttonHover.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        Row {
            id: buttonRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter

                visible: button.icon !== ""

                icon: button.icon
                size: Appearance.font.icon.small
                color: button.tint
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                text: button.text
                color: button.tint
                font.weight: Font.Medium
            }
        }
    }

    // The grid. Every cell is a fixed size, so the drop can be sent to
    // one before its tile has laid itself out.
    readonly property int columns: Math.max(1, Math.min(4, Themes.themes.length))
    readonly property int rows: Math.ceil(Themes.themes.length / columns)
    readonly property int tileWidth: 144
    readonly property int frameHeight: 90
    readonly property int cellHeight: frameHeight + Appearance.spacing.small + 20
    readonly property int gap: Appearance.spacing.medium

    // Past the grid, at most this many rows show and the rest scroll.
    readonly property int maxRows: 3

    // How far the drop shows round the selected tile.
    readonly property int ring: 4

    readonly property int pickedIndex: Themes.themes.findIndex(t => t.name === picker.picked)

    function cellX(i: int): real {
        return ring + (i % columns) * (tileWidth + gap);
    }

    function cellY(i: int): real {
        return ring + Math.floor(i / columns) * (cellHeight + gap);
    }

    // Steps the selection with the arrows: across wraps through the
    // whole list, up and down stop at the edges.
    function move(dx: int, dy: int): void {
        const n = Themes.themes.length;
        if (n === 0)
            return;
        let i = Math.max(0, pickedIndex);
        if (dx !== 0)
            i = (i + dx + n) % n;
        if (dy !== 0 && i + dy * columns >= 0 && i + dy * columns < n)
            i += dy * columns;

        // The keyboard takes over from the pointer until it moves again.
        picker.hovered = "";
        picker.picked = Themes.themes[i].name;

        const top = cellY(i) - ring;
        const bottom = top + cellHeight + ring * 2;
        if (top < flick.contentY)
            flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }

    // Applies the selection, flooding it out from the selected tile.
    function apply(): void {
        const tile = tileRepeater.itemAt(pickedIndex);
        const from = tile ? tile.wallpaperFrame : root;
        const p = from.mapToItem(null, from.width / 2, from.height / 2);
        picker.apply(Qt.point(screen.x + p.x, screen.y + p.y));
    }

    implicitWidth: content.implicitWidth + Appearance.padding.extraLarge * 2
    implicitHeight: content.implicitHeight + Appearance.padding.extraLarge * 2

    radius: Appearance.rounding.extraLarge
    color: tones.m3surfaceContainer

    // In as an M3 dialog comes in, rising a little out of the dim, and
    // out the same way.
    opacity: 0
    scale: 0.9

    Component.onCompleted: {
        opacity = Qt.binding(() => picker.shown ? 1 : 0);
        scale = Qt.binding(() => picker.shown ? 1 : 0.95);
        forceActiveFocus();
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    focus: true

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1, 0);
            break;
        case Qt.Key_Right:
            move(1, 0);
            break;
        case Qt.Key_Up:
            move(0, -1);
            break;
        case Qt.Key_Down:
            move(0, 1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            apply();
            break;
        case Qt.Key_Escape:
            picker.close();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Keeps a click on the card from reaching the dim, which would close.
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.medium

            StyledText {
                Layout.fillWidth: true

                text: qsTr("Theme")
                color: root.tones.m3onSurface
                font.pixelSize: Appearance.font.large
                font.weight: Font.Medium
            }

            ModeSegments {
                tones: root.tones
                mode: root.picker.pickedMode

                onPicked: mode => root.picker.pickedMode = mode
            }

            IconButton {
                icon: "close"
                color: root.tones.m3onSurfaceVariant
                iconSize: Appearance.font.icon.normal

                onActivated: root.picker.close()
            }
        }

        ThemePreview {
            Layout.fillWidth: true
            Layout.preferredHeight: 250

            tones: root.tones
            wallpaper: root.picker.previewInfo?.wallpaper ?? ""
            title: root.picker.displayName(root.picker.previewed)
            subtitle: root.picker.pickedMode === "light" ? qsTr("Light") : qsTr("Dark")
        }

        // The theme's main roles, popping in one after another whenever
        // a different theme comes up, and what Apply would do.
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: ["m3primary", "m3secondary", "m3tertiary", "m3primaryContainer", "m3surfaceContainerHighest"]

                Rectangle {
                    id: swatch

                    required property string modelData
                    required property int index

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    radius: width / 2
                    color: root.tones[modelData]
                    border.width: 1
                    border.color: root.tones.m3outlineVariant

                    Connections {
                        target: root.picker

                        function onPreviewedChanged(): void {
                            pop.restart();
                        }
                    }

                    SequentialAnimation {
                        id: pop

                        PauseAnimation {
                            duration: swatch.index * 40
                        }
                        Anim {
                            target: swatch
                            property: "scale"
                            to: 0.75
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: swatch
                            property: "scale"
                            to: 1
                            type: Anim.FastSpatial
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: {
                    const p = root.picker;
                    if (!p.changed)
                        return qsTr("In use");
                    if (p.picked === Themes.theme)
                        return p.pickedMode === "light" ? qsTr("Switches to light") : qsTr("Switches to dark");
                    return qsTr("Not applied yet");
                }
                color: root.tones.m3onSurfaceVariant
            }
        }

        Flickable {
            id: flick

            Layout.preferredWidth: grid.width
            Layout.preferredHeight: Math.min(grid.height, root.maxRows * (root.cellHeight + root.gap) - root.gap + root.ring * 2)

            contentWidth: grid.width
            contentHeight: grid.height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Behavior on contentY {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Item {
                id: grid

                width: root.columns * root.tileWidth + (root.columns - 1) * root.gap + root.ring * 2
                height: root.rows * root.cellHeight + Math.max(0, root.rows - 1) * root.gap + root.ring * 2

                // The selection, as liquid: a head that darts to the new
                // tile and a tail that follows on a slower spring, fused
                // into one drop that stretches across the gap between
                // them and draws back together as the tail arrives.
                BlobGroup {
                    id: liquid

                    color: root.tones.m3primary
                    smoothing: 24
                    cornerFill: false
                }

                Repeater {
                    model: [
                        {
                            type: Anim.FastSpatial
                        },
                        {
                            type: Anim.SlowSpatial
                        }
                    ]

                    BlobRect {
                        id: drop

                        required property var modelData

                        group: root.pickedIndex >= 0 ? liquid : null

                        x: root.cellX(Math.max(0, root.pickedIndex)) - root.ring
                        y: root.cellY(Math.max(0, root.pickedIndex)) - root.ring
                        width: root.tileWidth + root.ring * 2
                        height: root.frameHeight + root.ring * 2
                        radius: Appearance.rounding.extraLarge + root.ring

                        Behavior on x {
                            Anim {
                                type: drop.modelData.type
                            }
                        }

                        Behavior on y {
                            Anim {
                                type: drop.modelData.type
                            }
                        }
                    }
                }

                Repeater {
                    id: tileRepeater

                    model: Themes.themes

                    ThemeTile {
                        picker: root.picker

                        x: root.cellX(index)
                        y: root.cellY(index)
                        width: root.tileWidth
                        height: root.cellHeight
                        frameHeight: root.frameHeight

                        onApplied: root.apply()
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Appearance.spacing.small

            DialogButton {
                tones: root.tones
                text: qsTr("Cancel")

                onActivated: root.picker.close()
            }

            DialogButton {
                tones: root.tones
                text: qsTr("Apply")
                icon: "check"
                filled: true
                enabled: root.picker.changed

                onActivated: root.apply()
            }
        }
    }
}
