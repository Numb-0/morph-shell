import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config

// The theme being looked at, large: its wallpaper, with a small shell
// drawn over it in its colours -- a bar along the top, a card and a
// floating button -- so it shows what the desktop would look like
// rather than only the picture it came from.
//
// A new wallpaper fades in over the last rather than cutting, so
// sweeping across the tiles reads as one picture dissolving into the
// next.
ClippingRectangle {
    id: root

    required property ThemePalette tones

    property string wallpaper: ""
    property string title: ""
    property string subtitle: ""

    radius: Appearance.rounding.extraLarge
    color: tones.m3surfaceContainerHigh

    // Two layers that take turns: the new wallpaper loads into whichever
    // is behind, which is brought to the front and fades in over the one
    // still showing the last. Moving the last picture into the back layer
    // instead would load it again there, and leave nothing behind the new
    // one until it had.
    property Image front: first

    onWallpaperChanged: {
        const next = front === first ? second : first;
        next.opacity = 0;
        next.z = 1;
        front.z = 0;
        next.source = wallpaper ? `file://${wallpaper}` : "";
        front = next;
        if (next.status === Image.Ready)
            next.fadeIn();
    }

    component Layer: Image {
        id: layer

        function fadeIn(): void {
            fade.restart();
        }

        anchors.fill: parent

        // Twice the bubble's width, fixed rather than following it: the
        // bubble grows on the way in, and a size bound to it would decode
        // the picture again on every frame of that.
        sourceSize.width: 1240
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        opacity: 0

        onStatusChanged: {
            if (status === Image.Ready && z === 1)
                fade.restart();
        }

        Anim {
            id: fade

            target: layer
            property: "opacity"
            to: 1
            type: Anim.SlowEffects
        }
    }

    // Their own item, so bringing one to the front only orders them, and
    // never lifts a picture over the shell drawn on top.
    Item {
        anchors.fill: parent

        Layer {
            id: first
        }

        Layer {
            id: second
        }
    }

    // The bar: workspaces, the clock, and a few status glyphs.
    Rectangle {
        id: bar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.medium

        height: 30
        radius: height / 2
        color: root.tones.m3surfaceContainer

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.medium
            anchors.verticalCenter: parent.verticalCenter

            spacing: 5

            Repeater {
                model: 4

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter

                    width: index === 0 ? 20 : 8
                    height: 8
                    radius: 4

                    color: index === 0 ? root.tones.m3primary : root.tones.m3secondary
                    opacity: index === 0 ? 1 : 0.6
                }
            }
        }

        StyledText {
            anchors.centerIn: parent

            text: "12:30"
            color: root.tones.m3onSurface
            font.weight: Font.Medium
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.medium
            anchors.verticalCenter: parent.verticalCenter

            spacing: Appearance.spacing.small

            Repeater {
                model: ["wifi", "volume_up", "battery_5_bar"]

                MaterialSymbol {
                    required property string modelData

                    anchors.verticalCenter: parent.verticalCenter

                    icon: modelData
                    size: Appearance.font.icon.small - 2
                    color: root.tones.m3onSurface
                }
            }
        }
    }

    // A card: the theme's name and mode, a button and a switch.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        width: cardColumn.implicitWidth + Appearance.padding.large * 2
        height: cardColumn.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large
        color: root.tones.m3surfaceContainer

        Column {
            id: cardColumn

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            StyledText {
                text: root.title
                color: root.tones.m3onSurface
                font.pixelSize: Appearance.font.large
                font.weight: Font.Medium
            }

            StyledText {
                text: root.subtitle
                color: root.tones.m3onSurfaceVariant
            }

            Row {
                spacing: Appearance.spacing.medium
                topPadding: Appearance.spacing.extraSmall

                Rectangle {
                    width: buttonText.implicitWidth + Appearance.padding.large * 2
                    height: 28
                    radius: height / 2
                    color: root.tones.m3primary

                    StyledText {
                        id: buttonText

                        anchors.centerIn: parent

                        text: qsTr("Button")
                        color: root.tones.m3onPrimary
                        font.weight: Font.Medium
                    }
                }

                // A switch, on.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    width: 40
                    height: 24
                    radius: height / 2
                    color: root.tones.m3primary

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter

                        width: 16
                        height: 16
                        radius: 8
                        color: root.tones.m3onPrimary
                    }
                }
            }
        }
    }

    // A floating action button.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        width: 52
        height: 52
        radius: Appearance.rounding.large
        color: root.tones.m3primaryContainer

        MaterialSymbol {
            anchors.centerIn: parent

            icon: "palette"
            size: Appearance.font.icon.large - 4
            color: root.tones.m3onPrimaryContainer
            fill: 1
        }
    }
}
