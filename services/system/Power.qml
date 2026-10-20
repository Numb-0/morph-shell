pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The battery, as the bar wants it: one charge, one state, and the
// glyph that goes with them.
//
// Named for the supply rather than the battery so the bar widget can be
// called Battery without shadowing this.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    // UPower hands back a display device on a desktop too, with nothing
    // to report. Ask this before drawing anything, rather than sitting
    // in the bar showing a permanent 0%.
    readonly property bool available: (device?.ready ?? false) && (device?.isLaptopBattery ?? false)

    // 0..1, as UPower reports it.
    readonly property real percentage: device?.percentage ?? 0

    readonly property int deviceState: device?.state ?? UPowerDeviceState.Unknown

    readonly property bool charging: deviceState === UPowerDeviceState.Charging || deviceState === UPowerDeviceState.PendingCharge
    readonly property bool full: deviceState === UPowerDeviceState.FullyCharged

    // Only ever true on battery: a charging cell passing through 15% is
    // on its way up and wants no attention.
    readonly property bool low: !charging && !full && percentage <= 0.2
    readonly property bool critical: !charging && !full && percentage <= 0.1

    // A notification as the charge passes each of these on battery.
    // Each fires once per discharge, so a reading wobbling across the
    // line does not repeat it, and only the lowest one crossed is sent:
    // waking from suspend at 8% warns about 10%, not 20% then 10%.
    readonly property list<int> warnings: [10, 20]

    // The lowest threshold already warned about. Plugging in resets it.
    property int warnedAt: 101

    readonly property int level: Math.round(percentage * 100)

    onLevelChanged: checkLevel()
    onChargingChanged: checkLevel()
    onAvailableChanged: checkLevel()

    function checkLevel(): void {
        if (!available || charging || full || !UPower.onBattery) {
            warnedAt = 101;
            return;
        }

        const threshold = warnings.find(t => level <= t && t < warnedAt);
        if (threshold === undefined)
            return;

        warnedAt = threshold;
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", threshold <= 10 ? "critical" : "normal", "-i", "battery-caution", qsTr("Battery low"), qsTr("%1% remaining").arg(level)]);
    }

    readonly property bool healthSupported: device?.healthSupported ?? false

    // Normalised to 0..1 to match `percentage`. UPower reports health on
    // a 0..100 scale, so anything above 1 is taken as a percentage --
    // which also leaves a genuine 0..1 report alone.
    readonly property real health: {
        const value = device?.healthPercentage ?? 0;
        return value > 1 ? value / 100 : value;
    }

    // Seconds until full or empty. UPower reports 0 while it has no rate
    // to work from -- for a minute or so after a plug or unplug, and
    // whenever the draw is too erratic to extrapolate -- so read it as
    // "not known yet" rather than "no time left".
    readonly property real timeRemaining: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)

    readonly property string status: {
        if (full)
            return qsTr("Fully charged");
        if (charging)
            return qsTr("Charging");
        if (deviceState === UPowerDeviceState.Empty)
            return qsTr("Empty");
        if (deviceState === UPowerDeviceState.PendingDischarge || !UPower.onBattery)
            return qsTr("Plugged in");
        return qsTr("On battery");
    }

    // Seven steps either way. The thresholds sit above each step's own
    // range so a battery reading 84% shows five bars rather than the six
    // it has not got back to yet.
    readonly property string icon: {
        if (!charging && percentage <= 0.05)
            return "battery_alert";

        if (charging) {
            if (percentage >= 0.95)
                return "battery_charging_full";
            if (percentage >= 0.85)
                return "battery_charging_90";
            if (percentage >= 0.7)
                return "battery_charging_80";
            if (percentage >= 0.55)
                return "battery_charging_60";
            if (percentage >= 0.4)
                return "battery_charging_50";
            if (percentage >= 0.25)
                return "battery_charging_30";
            return "battery_charging_20";
        }

        if (percentage >= 0.95)
            return "battery_full";
        if (percentage >= 0.85)
            return "battery_6_bar";
        if (percentage >= 0.7)
            return "battery_5_bar";
        if (percentage >= 0.55)
            return "battery_4_bar";
        if (percentage >= 0.4)
            return "battery_3_bar";
        if (percentage >= 0.25)
            return "battery_2_bar";
        return "battery_1_bar";
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.round(seconds));
        const hours = Math.floor(total / 3600);
        const mins = Math.floor((total % 3600) / 60);

        if (hours > 0)
            return qsTr("%1h %2m").arg(hours).arg(mins);
        return qsTr("%1m").arg(mins);
    }
}
