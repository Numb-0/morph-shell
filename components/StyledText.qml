import QtQuick
import qs.config

Text {
    id: root

    property bool animate: false

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter

    color: Appearance.palette.m3onSurface
    font.family: Appearance.font.family
    font.pixelSize: Appearance.font.small

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }

            PropertyAction {
                target: root
                property: "text"
            }

            Anim {
                target: root
                property: "opacity"
                to: 1
                type: Anim.FastEffects
            }
        }
    }
}
