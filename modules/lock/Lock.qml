pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.config
import qs.services.launcher
import qs.services.session

// The session lock, standing in for hyprlock. The compositor hands every
// screen to the lock's surfaces and keeps the session locked until the
// shell says otherwise -- even if the shell dies first, so a crash never
// leaves the desktop open.
//
// It locks on its own after the idle timeout (see Idle), on logind's
// lock requests -- `loginctl lock-session`, the session menu's Lock --
// and before the machine sleeps, holding the sleep back until the lock
// is up so the desktop never shows for a frame on waking.
//
// The password is typed into one buffer shared by every screen, so it
// does not matter which one the keyboard lands on. PAM only starts on
// Enter, and goes through the whole conversation once per try.
Scope {
    id: root

    property string buffer: ""

    // Between Enter and PAM's answer. The buffer is held as it was, dots
    // and all, until the answer comes.
    property bool checking: false

    // Set by a failed try, and cleared by typing so the warning does not
    // hang over the next one.
    property bool wrong: false

    // The right password went in: the field turns to a tick and the lock
    // fades back to the bare wallpaper before letting go.
    property bool unlocking: false

    // The last stretch of that, once the tick has had its moment.
    property bool leaving: false

    // What PAM had to say that is worth showing: an account locked out
    // after too many tries, a service that would not start.
    property string message: ""

    // One answer per try. A PAM stack that asks twice gets nothing the
    // second time and fails, rather than the password sent on to what
    // is likely a code prompt.
    property bool answered: false

    signal failed

    // A dedicated PAM service when there is one (the NixOS module adds
    // it), and login's otherwise, so a system without it still unlocks.
    property bool hasOwnService: false

    function lock(): void {
        if (sessionLock.locked)
            return;
        buffer = "";
        checking = false;
        wrong = false;
        unlocking = false;
        leaving = false;
        message = "";
        sessionLock.locked = true;
    }

    function type(text: string): void {
        if (checking || unlocking)
            return;
        wrong = false;
        buffer += text;
    }

    function erase(all: bool): void {
        if (checking || unlocking)
            return;
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function submit(): void {
        if (checking || unlocking || buffer === "")
            return;
        checking = true;
        answered = false;
        message = "";
        if (pam.active)
            pam.abort();
        if (!pam.start()) {
            checking = false;
            message = qsTr("Could not start authentication");
        }
    }

    PamContext {
        id: pam

        config: root.hasOwnService ? "morph-shell" : "login"

        onPamMessage: {
            if (responseRequired) {
                if (!root.answered && root.checking) {
                    root.answered = true;
                    respond(root.buffer);
                } else {
                    abort();
                }
            } else if (messageIsError) {
                root.message = message;
            }
        }

        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                // Unlocking before the buffer empties, so the field
                // gathers its dots into the tick rather than wiping them.
                root.unlocking = true;
                root.buffer = "";
                fadeOut.restart();
                release.restart();
            } else {
                // Wrong before the buffer empties, so the dots fall out
                // of the field rather than being wiped.
                root.wrong = true;
                root.buffer = "";
                if (result === PamResult.MaxTries)
                    root.message = qsTr("Too many tries");
                root.failed();
            }
        }

        onError: error => {
            root.checking = false;
            root.message = qsTr("Authentication error: %1").arg(PamError.toString(error));
            console.warn(`lock: pam error ${PamError.toString(error)}`);
        }
    }

    FileView {
        path: "/etc/pam.d/morph-shell"
        printErrors: false

        onLoaded: root.hasOwnService = true
        onLoadFailed: root.hasOwnService = false
    }

    // Once the dots have melted into the drop and the tick is in it.
    Timer {
        id: fadeOut

        interval: 750
        onTriggered: root.leaving = true
    }

    // Long enough for the fade in LockSurface to play out after it.
    Timer {
        id: release

        interval: 1150
        onTriggered: {
            sessionLock.locked = false;
            root.unlocking = false;
            root.leaving = false;
        }
    }

    // From the launcher's commands.
    Connections {
        target: Commands

        function onLockRequested(): void {
            root.lock();
        }
    }

    Connections {
        target: Idle

        function onLockRequested(): void {
            root.lock();
        }
    }

    // The user's own sessions, for telling their lock requests from
    // another user's. Until they are known, every request counts.
    property list<string> sessions: []

    Process {
        running: true

        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1/user/self", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.User", "Sessions"]

        // (<[('2', objectpath '/org/freedesktop/login1/session/_32'), ('1', '/org/freedesktop/login1/session/_31')]>,)
        //
        // Only the first path is marked as one, so they are told apart by
        // where they point instead.
        stdout: StdioCollector {
            onStreamFinished: root.sessions = (text.match(/'\/org\/freedesktop\/login1\/session\/[^']+'/g) ?? []).map(path => path.slice(1, -1))
        }
    }

    // logind's signals, one per line:
    //
    //   /org/freedesktop/login1/session/_32: org.freedesktop.login1.Session.Lock ()
    //   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
    //
    // Subscribed to rather than eavesdropped on, so it needs no rights on
    // the system bus.
    Process {
        id: logind

        running: true

        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]

        stdout: SplitParser {
            onRead: line => {
                const match = line.match(/^(\S+): org\.freedesktop\.login1\.(\S+) \((.*)\)$/);
                if (!match)
                    return;

                const [, path, member, args] = match;
                if (member === "Session.Lock" && (root.sessions.length === 0 || root.sessions.includes(path)))
                    root.lock();
                else if (member === "Manager.PrepareForSleep")
                    root.sleeping = args.startsWith("true");
            }
        }

        // The bus restarting takes the monitor with it.
        onExited: logindRetry.start()
    }

    Timer {
        id: logindRetry

        interval: 5000
        onTriggered: logind.running = true
    }

    // Between logind saying the machine is going to sleep and it waking.
    property bool sleeping: false

    onSleepingChanged: {
        if (sleeping) {
            if (Appearance.idle.lockBeforeSleep)
                root.lock();
        } else {
            lockDrawn = false;
            Idle.wake();
        }
    }

    // Holds sleep back while the lock comes up -- logind waits for this
    // to let go, or a few seconds at most. Let go once the compositor
    // says every screen is covered, with a moment more for the frame to
    // reach the panel, and taken again on waking for the next time.
    property bool lockDrawn: false

    Timer {
        running: root.sleeping && sessionLock.secure
        interval: 150

        onTriggered: root.lockDrawn = true
    }

    Process {
        running: Appearance.idle.lockBeforeSleep && !(root.sleeping && root.lockDrawn)

        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=morph-shell", "--why=Locking the screen first", "sleep", "infinity"]
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        // Read off the lock each time rather than through a binding:
        // WlSessionLock only signals the change when it unlocks, so a
        // bound copy would still say false while locked.
        function isLocked(): bool {
            return sessionLock.locked;
        }
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            lock: root
        }
    }
}
