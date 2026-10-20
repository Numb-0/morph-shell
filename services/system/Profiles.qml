pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// power-profiles-daemon, as the bar wants it: which profile is active,
// the glyph for it, and a way to step to the next one. Talks to the
// daemon over D-Bus through Quickshell rather than through
// powerprofilesctl, so there is no process per change.
Singleton {
    id: root

    // Quickshell's PowerProfiles reads as Balanced with no daemon at
    // all, and has nothing that says the daemon is missing. So ask the
    // bus once: a machine without it (or with TLP in its place) hides
    // the widget rather than showing a switch that does nothing.
    property bool available: false

    readonly property int profile: PowerProfiles.profile

    // Performance only exists on hardware with a driver for it. Where it
    // is missing it is skipped when cycling rather than offered and
    // refused.
    readonly property var profiles: PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    // The daemon can hold performance back -- the laptop running hot, or
    // on a lap -- and says so. Surfaced so the widget can show that
    // performance was asked for but is not being delivered.
    readonly property bool degraded: profile === PowerProfile.Performance && PowerProfiles.degradationReason !== PerformanceDegradationReason.None

    readonly property string icon: {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "energy_savings_leaf";
        case PowerProfile.Performance:
            return "bolt";
        default:
            return "balance";
        }
    }

    readonly property string label: {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return qsTr("Power saver");
        case PowerProfile.Performance:
            return qsTr("Performance");
        default:
            return qsTr("Balanced");
        }
    }

    function set(value: int): void {
        if (available)
            PowerProfiles.profile = value;
    }

    // Forward on a click, backward on a right click, wrapping at both
    // ends.
    function cycle(step: int): void {
        const at = profiles.indexOf(profile);
        const next = ((at < 0 ? 1 : at) + step + profiles.length) % profiles.length;
        set(profiles[next]);
    }

    Process {
        running: true

        command: ["dbus-send", "--system", "--print-reply=literal", "--dest=org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.DBus.Peer.Ping"]

        onExited: code => root.available = code === 0
    }
}
