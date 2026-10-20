import QtQuick

// Seconds without input before each step, counted from the last
// input rather than from the step before. 0 turns a step off.
QtObject {
    // The backlight drops to `dimTo` of where it was, a warning that
    // the lock is coming; any input puts it back.
    readonly property int dim: 270
    readonly property real dimTo: 0.3

    readonly property int lock: 300

    // Lock as the machine goes to sleep, whatever the timers say.
    readonly property bool lockBeforeSleep: true

    // Hyprland only.
    readonly property int screenOff: 420
}
