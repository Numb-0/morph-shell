import QtQuick
import qs.config

// One glyph from Material Symbols.
//
// The font is variable on four axes. FILL rounds an icon out from an
// outline to a solid and GRAD thickens its strokes, and neither changes
// the glyph's advance -- so both can be animated without the row they
// sit in shifting. opsz is tied to the pixel size, which is what the
// axis is for: it thins the strokes optically as the icon grows.
Text {
    id: root

    required property string icon

    property real fill: 0
    property real grad: 0
    property real weight: 400
    property int size: Appearance.font.icon.normal

    text: icon
    color: Appearance.palette.text

    font.family: Appearance.font.material
    font.pixelSize: size
    font.variableAxes: ({
            FILL: root.fill,
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
}
