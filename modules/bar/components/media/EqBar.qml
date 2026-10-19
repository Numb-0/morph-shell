import QtQuick
import qs.config

// One bar of the placeholder's equaliser. It bobs on its own period,
// so a few side by side never move in step, and only as far as
// energy lets it: at rest it is a short pill.
Rectangle {
    id: bar

    required property int period
    property real energy: 0
    property real level: 0.5

    anchors.bottom: parent?.bottom

    width: 8
    height: 10 + level * energy * 36
    radius: width / 2
    color: Appearance.palette.m3onPrimaryContainer

    // Only while it is seen and has somewhere to go; hidden or
    // paused, nothing should keep the animation driver ticking.
    SequentialAnimation on level {
        running: bar.visible && bar.energy > 0
        loops: Animation.Infinite

        NumberAnimation {
            to: 1
            duration: bar.period
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            to: 0.15
            duration: bar.period
            easing.type: Easing.InOutSine
        }
    }
}
