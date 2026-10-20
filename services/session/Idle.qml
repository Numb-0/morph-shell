pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services.system

// What happens as the session sits untouched, standing in for hypridle:
// the backlight dims, then the session locks, then the screens go off.
// Each step is timed from the last input, so the steps run side by side
// rather than one after the other, and any input undoes them all.
//
// A window asking the compositor to stay up -- a video playing, a call
// -- holds every step off, as does `awake`, the shell's own switch for
// the same. Only Wayland's idle inhibitors count: the D-Bus ScreenSaver
// ones some X11 apps take are not heard.
//
// Locking is asked for rather than done, since the lock is a module of
// its own; locking before sleep is the lock's, as it has to hold the
// sleep back until it is drawn.
Singleton {
    id: root

    property bool awake: false

    signal lockRequested

    function toggleAwake(): void {
        awake = !awake;
    }

    readonly property bool onHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

    // Set around the backlight moves made here, so the OSD can tell the
    // dim from someone turning the brightness down.
    property bool adjusting: false

    // Where the backlight was before the dim, to go back to; -1 while
    // not dimmed.
    property real undimmed: -1

    property bool screenOff: false

    function dim(): void {
        if (undimmed >= 0 || !Backlight.available)
            return;

        undimmed = Backlight.brightness;
        setBacklight(undimmed * Config.idle.dimTo);
    }

    function undim(): void {
        if (undimmed < 0)
            return;

        // Unless something else has moved it since: a brightness key
        // pressed in the dark counts as input and lands here, and its
        // new level is the one to keep.
        if (Backlight.available && Math.abs(Backlight.brightness - undimmed * Config.idle.dimTo) < 0.01)
            setBacklight(undimmed);
        undimmed = -1;
    }

    function setBacklight(value: real): void {
        adjusting = true;
        Backlight.setBrightness(value);
        adjusting = false;
    }

    function setScreens(on: bool): void {
        if (!onHyprland || screenOff === !on)
            return;

        screenOff = !on;
        Hyprland.dispatch(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`);
    }

    // For waking from sleep, where the screens can come back off
    // whatever was asked of them before.
    function wake(): void {
        undim();
        screenOff = true;
        setScreens(true);
    }

    onAwakeChanged: {
        if (awake) {
            undim();
            setScreens(true);
        }
    }

    IdleMonitor {
        enabled: !root.awake && Config.idle.dim > 0
        timeout: Config.idle.dim

        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }

    IdleMonitor {
        enabled: !root.awake && Config.idle.lock > 0
        timeout: Config.idle.lock

        onIsIdleChanged: {
            if (isIdle)
                root.lockRequested();
        }
    }

    IdleMonitor {
        enabled: !root.awake && root.onHyprland && Config.idle.screenOff > 0
        timeout: Config.idle.screenOff

        onIsIdleChanged: root.setScreens(!isIdle)
    }

    //   qs -p ~/morph-shell ipc call idle toggleAwake
    IpcHandler {
        target: "idle"

        function toggleAwake(): void {
            root.toggleAwake();
        }

        function setAwake(awake: bool): void {
            root.awake = awake;
        }

        function isAwake(): bool {
            return root.awake;
        }
    }
}
