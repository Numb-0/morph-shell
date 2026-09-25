import QtQuick
import qs.config

// A NumberAnimation preset to the Material 3 Expressive motion tokens.
// Spatial types move things and overshoot a little before settling;
// effects types fade or recolour and do not.
NumberAnimation {
    enum Type {
        DefaultSpatial,
        FastSpatial,
        SlowSpatial,
        DefaultEffects,
        FastEffects,
        SlowEffects,
        Standard,
        Emphasized
    }

    property int type: Anim.DefaultSpatial

    duration: {
        switch (type) {
        case Anim.FastSpatial:
            return Appearance.anim.durations.fastSpatial;
        case Anim.SlowSpatial:
            return Appearance.anim.durations.slowSpatial;
        case Anim.DefaultEffects:
            return Appearance.anim.durations.defaultEffects;
        case Anim.FastEffects:
            return Appearance.anim.durations.fastEffects;
        case Anim.SlowEffects:
            return Appearance.anim.durations.slowEffects;
        case Anim.Standard:
        case Anim.Emphasized:
            return Appearance.anim.durations.standard;
        default:
            return Appearance.anim.durations.defaultSpatial;
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (type) {
        case Anim.FastSpatial:
            return Appearance.anim.fastSpatial;
        case Anim.SlowSpatial:
            return Appearance.anim.slowSpatial;
        case Anim.DefaultEffects:
            return Appearance.anim.defaultEffects;
        case Anim.FastEffects:
            return Appearance.anim.fastEffects;
        case Anim.SlowEffects:
            return Appearance.anim.slowEffects;
        case Anim.Standard:
            return Appearance.anim.standard;
        case Anim.Emphasized:
            return Appearance.anim.emphasized;
        default:
            return Appearance.anim.defaultSpatial;
        }
    }
}
