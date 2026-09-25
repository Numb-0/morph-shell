import QtQuick
import qs.config

// Colour transitions, on the slow effects curve.
ColorAnimation {
    duration: Appearance.anim.durations.slowEffects

    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.slowEffects
}
