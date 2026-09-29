import QtQuick
import qs.config

// One glyph from Material Symbols.
//
// The font is variable on four axes. FILL rounds an icon out from an
// outline to a solid and GRAD thickens its strokes, and neither changes
// the glyph's advance -- so both can be animated without the row they
// sit in shifting. opsz is tied to the pixel size, which is what the
// axis is for: it thins the strokes optically as the icon grows.
//
// FILL is never handed to the font as an in-between value. Qt builds a
// separate font engine (its own mapping of the 15 MB file and its own
// glyph cache) for every distinct set of axes and keeps them around, so
// animating the axis itself left dozens of engines behind per toggle.
// The glyph only ever uses FILL 0 or 1; in between, a solid copy on top
// fades in with the fill.
Text {
    id: root

    required property string icon

    property real fill: 0
    property real grad: 0
    property real weight: 400
    property int size: Appearance.font.icon.normal

    text: icon
    color: Appearance.palette.m3onSurface

    font.family: Appearance.font.material
    font.pixelSize: size
    font.variableAxes: ({
            FILL: root.fill >= 1 ? 1 : 0,
            GRAD: root.grad,
            opsz: root.size,
            wght: root.weight
        })

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color {
        CAnim {}
    }

    Behavior on fill {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Text {
        anchors.fill: parent

        visible: root.fill > 0 && root.fill < 1
        opacity: root.fill

        text: root.text
        color: root.color

        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        font.variableAxes: ({
                FILL: 1,
                GRAD: root.grad,
                opsz: root.size,
                wght: root.weight
            })

        renderType: root.renderType
        textFormat: root.textFormat
        verticalAlignment: root.verticalAlignment
        horizontalAlignment: root.horizontalAlignment
    }
}
