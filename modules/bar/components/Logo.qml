import QtQuick
import QtQuick.Effects
import qs.components
import qs.config

// Bar widget: the NixOS snowflake, sitting at the start of the bar.
//
// The SVG is used only as a mask over a rectangle of the palette's
// primary, so the glyph takes the theme's colour exactly rather than
// whatever the file was drawn in.
Item {
    id: root

    property int size: Appearance.font.icon.normal + 2

    implicitWidth: size + Appearance.padding.large * 2
    implicitHeight: size + Appearance.padding.small * 2

    Image {
        id: glyph

        anchors.centerIn: parent
        width: root.size
        height: root.size

        source: Qt.resolvedUrl("../../../assets/icons/flake.svg")
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true

        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: glyph

        color: Appearance.palette.primary

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: glyph

            // Keeps the SVG's antialiased edges instead of a hard cut.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Behavior on color {
            CAnim {}
        }
    }
}
