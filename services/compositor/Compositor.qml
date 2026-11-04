pragma Singleton

import QtQuick
import Quickshell

// Which compositor the shell runs under, and the few things the shell
// asks of one: which screen has focus, the keyboard layout, turning the
// screens off and ending the session. Each is answered the same way
// whatever is underneath, so the rest of the shell never asks which.
//
// Hyprland comes through Hypr, niri through Niri. Anywhere else, the
// answers are the plain fallbacks: the first screen, no layout, screens
// left on, logind.
//
// What one compositor can do and another cannot is said by the `has*`
// flags, for the features that have no fallback worth the name.
Singleton {
    id: root

    readonly property bool isHyprland: Hypr.available
    readonly property bool isNiri: !isHyprland && Niri.available

    // A click outside a panel, on any screen, takes it away: a Hyprland
    // focus grab. Elsewhere only a click on the same screen does.
    readonly property bool hasFocusGrab: isHyprland

    // Window positions and the shell's own overview, both from
    // Hyprland's IPC. niri has an overview of its own instead.
    readonly property bool hasWindowLayout: isHyprland

    readonly property bool canPowerScreens: isHyprland || isNiri

    // The focused screen's name, or the first screen's where there is
    // no focus to ask about.
    readonly property string focusedScreen: {
        const name = isHyprland ? Hypr.focusedMonitor : isNiri ? Niri.focusedOutput : "";
        return name || (Quickshell.screens[0]?.name ?? "");
    }

    // The keyboard layout's name, as the compositor spells it; empty
    // where there is no telling.
    readonly property string layout: isHyprland ? Hypr.layout : isNiri ? Niri.layout : ""

    function setScreens(on: bool): void {
        if (isHyprland)
            Hypr.setScreens(on);
        else if (isNiri)
            Niri.action(on ? "power-on-monitors" : "power-off-monitors");
    }

    // A shell run as a user service has no session id of its own to
    // end, so the last resort is every session the user has.
    readonly property var logoutCommand: {
        if (isHyprland)
            return Hypr.logoutCommand;
        if (isNiri)
            return ["niri", "msg", "action", "quit", "--skip-confirmation"];
        const session = Quickshell.env("XDG_SESSION_ID");
        if (session)
            return ["loginctl", "terminate-session", session];
        return ["loginctl", "terminate-user", Quickshell.env("USER")];
    }
}
