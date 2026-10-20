pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services.launcher

// The session menu, full screen: lock, log out, suspend, restart and
// shut down as a row of large tonal buttons over the wallpaper, which
// comes and goes the way the lock does -- the picture fades up over the
// desktop and dims, and the clock and buttons rise in over it.
//
// Opened from the bar's power glyph, the launcher's `:session` or a
// bind. The arrows choose, Enter takes it, Escape backs out.
//
// The actions that end the session take a second press, so a stray
// click on the way past cannot take the machine down:
// the first arms the button -- it fills with the error colour, shakes
// as the lock's field does on a wrong try, and asks to be confirmed.
//
// Taking an action plays the lock's success in its own terms: the other
// buttons draw in to the chosen one and melt into it, then everything
// fades back to the desktop. The command only runs once the menu has
// gone, so a suspend or a lock never comes back to it still up.
Scope {
    id: root

    // Loaded, and drawn. Closing fades it out before unloading it, so the
    // two part for the length of the fade.
    property bool active: false
    property bool shown: false

    // The screen the buttons and the keyboard go to, chosen once on
    // opening. Every other screen only dims.
    property string keyScreen: ""

    // The button under the keyboard's selection, by index.
    property int selected: 0

    // Which action is waiting on its confirming press, if any.
    property string armed: ""

    // An action has been taken: the buttons gather into the chosen one
    // and the menu fades on its way out. Nothing answers in between.
    property bool committing: false

    // What runs once the menu has gone.
    property var pending: null

    signal armedAction(int index)
    signal committed(int index)

    // Off Hyprland the logout falls back on logind. A shell run as a user
    // service has no session id of its own to end, so the last resort is
    // every session the user has.
    readonly property var logoutCommand: {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return ["hyprctl", "dispatch", "exit"];
        const session = Quickshell.env("XDG_SESSION_ID");
        if (session)
            return ["loginctl", "terminate-session", session];
        return ["loginctl", "terminate-user", Quickshell.env("USER")];
    }

    readonly property list<var> actions: [
        {
            // Through logind, so whichever locker the session has wired to
            // lock requests -- this shell's own, or hyprlock -- is the
            // one that comes up.
            name: "lock",
            icon: "lock",
            label: qsTr("Lock"),
            command: ["loginctl", "lock-session"],
            confirm: false
        },
        {
            name: "logout",
            icon: "logout",
            label: qsTr("Log out"),
            command: root.logoutCommand,
            confirm: true
        },
        {
            name: "suspend",
            icon: "bedtime",
            label: qsTr("Suspend"),
            command: ["systemctl", "suspend"],
            confirm: false
        },
        {
            name: "reboot",
            icon: "restart_alt",
            label: qsTr("Restart"),
            command: ["systemctl", "reboot"],
            confirm: true
        },
        {
            name: "poweroff",
            icon: "power_settings_new",
            label: qsTr("Shut down"),
            command: ["systemctl", "poweroff"],
            confirm: true
        }
    ]

    function open(): void {
        if (shown)
            return;
        unload.stop();
        commit.stop();
        keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        selected = 0;
        armed = "";
        committing = false;
        pending = null;
        active = true;
        shown = true;
    }

    function close(): void {
        if (!shown)
            return;
        shown = false;
        disarm.stop();
        unload.restart();
    }

    function toggle(): void {
        if (shown)
            close();
        else
            open();
    }

    function select(index: int): void {
        if (committing)
            return;
        const n = actions.length;
        index = ((index % n) + n) % n;
        if (index !== selected)
            armed = "";
        selected = index;
    }

    function run(index: int): void {
        if (committing || index < 0 || index >= actions.length)
            return;

        selected = index;
        const action = actions[index];

        if (action.confirm && armed !== action.name) {
            armed = action.name;
            disarm.restart();
            root.armedAction(index);
            return;
        }

        // Left armed through the way out, so the label and the hint keep
        // what they said as they fade rather than flipping back first.
        disarm.stop();
        committing = true;
        pending = action.command;
        root.committed(index);
        commit.restart();
    }

    // Escape steps back one thing at a time: an armed button first, then
    // the menu.
    function back(): void {
        if (committing)
            return;
        if (armed !== "") {
            armed = "";
            disarm.stop();
        } else {
            close();
        }
    }

    // An armed button gives up on its own if it is not confirmed.
    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    // Once the buttons have melted into the chosen one.
    Timer {
        id: commit

        interval: 520
        onTriggered: root.close()
    }

    // Long enough for the slowest fade on the way out to play.
    Timer {
        id: unload

        interval: Appearance.anim.durations.slowEffects + 50
        onTriggered: {
            root.active = false;
            const command = root.pending;
            root.pending = null;
            root.committing = false;
            root.armed = "";
            if (command)
                Quickshell.execDetached(command);
        }
    }

    // From the launcher's commands and the bar's power glyph.
    Connections {
        target: Commands

        function onSessionRequested(): void {
            root.open();
        }
    }

    //   morph-shell ipc call session toggle
    IpcHandler {
        target: "session"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }

    LazyLoader {
        active: root.active

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                readonly property bool main: modelData.name === root.keyScreen

                screen: modelData
                color: "transparent"

                // Over everything, the bar and notifications included,
                // and reserving nothing. Only the menu's screen takes the
                // keyboard.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-session"
                WlrLayershell.keyboardFocus: main && root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                SessionSurface {
                    anchors.fill: parent

                    menu: root
                    screen: win.modelData
                    main: win.main
                }
            }
        }
    }
}
