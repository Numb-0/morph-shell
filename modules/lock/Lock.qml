pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The session lock, standing in for hyprlock. The compositor hands every
// screen to the lock's surfaces and keeps the session locked until the
// shell says otherwise -- even if the shell dies first, so a crash never
// leaves the desktop open.
//
// Nothing here listens to logind. Point the idle daemon's lock_cmd at
// `morph-shell ipc call lock lock`, and `loginctl lock-session` (from the
// session panel, or hypridle's own timeout) comes through that way.
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
