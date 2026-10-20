import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

// One transport control: a pill stretched across its share of the
// row. The primary one is filled and takes a wider share, as the
// action the panel is mostly opened for; the others are tonal. A
// toggle is narrower and takes no share at all: bare while off,
// filled with the secondary container while on.
Item {
    id: btn

    required property string icon
    property bool primary: false
    property bool toggle: false
    property bool checked: false

    signal activated

    implicitWidth: toggle ? 36 : 48
    implicitHeight: 48

    Layout.fillWidth: !toggle
    Layout.horizontalStretchFactor: primary ? 2 : 1

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            glyph.press();
            btn.activated();
        }
    }

    // A toggle's is a circle in the middle of the row's height.
    Rectangle {
        anchors.centerIn: parent

        width: parent.width
        height: btn.toggle ? width : parent.height
        radius: height / 2
        color: btn.primary ? Colours.palette.m3primary : btn.toggle ? Qt.alpha(Colours.palette.m3secondaryContainer, btn.checked ? 1 : 0) : Colours.palette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        // The M3 state layer.
        Rectangle {
            anchors.fill: parent

            radius: parent.radius
            color: btn.primary ? Colours.palette.m3onPrimary : btn.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            opacity: hover.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }

    MaterialSymbol {
        id: glyph

        anchors.centerIn: parent

        icon: btn.icon
        size: btn.primary ? Appearance.font.icon.large : Appearance.font.icon.normal
        color: btn.primary ? Colours.palette.m3onPrimary : btn.toggle ? (btn.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant) : Colours.palette.m3onSurface

        // Solid, as the drawn icons were -- transport controls read
        // as buttons rather than as outlines.
        fill: 1
    }
}
