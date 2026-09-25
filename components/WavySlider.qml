import QtQuick
import QtQuick.Templates as T
import Morph.Components
import qs.config

// Material-style progress slider: the elapsed side is a travelling wave,
// the remaining side a flat track, and the handle rides the wave rather
// than sitting on the centre line.
T.Slider {
    id: root

    property bool wavy: true
    property bool animateWave: wavy && enabled
    property int waveFrequency: 6
    property int waveDuration: 1600
    property int trackWidth: 3
    property int trackGap: Appearance.spacing.extraSmall
    property real amplitude: wavy ? 6 : 0
    property int handleSize: 11

    property color activeColor: Appearance.palette.primary
    property color inactiveColor: Qt.alpha(Appearance.palette.subtext, 0.35)

    // Owned here rather than inside the WavyLine so the handle can sample
    // the same wave and sit on it.
    property real waveProgress: 0

    readonly property real handleX: visualPosition * (width - handleSize)

    function waveY(x: real): real {
        const theta = waveFrequency * 2 * Math.PI * x / Math.max(1, width) + waveProgress * 2 * Math.PI;
        return height / 2 + amplitude * Math.sin(theta);
    }

    implicitWidth: 240
    implicitHeight: 24

    Behavior on amplitude {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    NumberAnimation on waveProgress {
        running: root.animateWave
        from: 0
        to: 1
        duration: root.waveDuration
        loops: Animation.Infinite
    }

    background: Item {
        anchors.fill: parent

        WavyLine {
            y: 0
            width: Math.max(0, root.handleX - root.trackGap)
            height: parent.height

            lineWidth: root.trackWidth
            amplitudeMultiplier: root.amplitude / Math.max(1, root.trackWidth)
            frequency: root.waveFrequency

            // Referenced against the whole slider so the wavelength stays
            // put as the elapsed portion grows.
            fullLength: root.width
            value: 1
            waveProgress: root.waveProgress

            color: root.activeColor
        }

        Rectangle {
            x: root.handleX + root.handleSize + root.trackGap
            y: (parent.height - height) / 2

            width: Math.max(0, parent.width - x)
            height: root.trackWidth

            radius: height / 2
            color: root.inactiveColor
        }
    }

    handle: Rectangle {
        x: root.handleX
        y: root.waveY(root.handleX + root.handleSize / 2) - height / 2

        implicitWidth: root.handleSize
        implicitHeight: root.handleSize

        radius: width / 2
        color: root.activeColor
    }
}
