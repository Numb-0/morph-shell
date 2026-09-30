pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon, as the shell wants it: everything that has
// arrived and not been dismissed, for the notification centre, and the
// ones still showing as popups.
//
// After frame-shell's NotificationManager: the server hands over each
// notification once and a wrapper is made for it here. The wrapper owns
// the popup's countdown rather than the popup itself, so every screen
// shows the same toast running out at the same moment, and a pointer
// resting on any of them holds all of them.
//
// Named Notifs rather than Notifications so the bar widget can have that
// name, and so neither shadows the module's own types.
Singleton {
    id: root

    // Newest first. Timed out popups stay here until dismissed; that is
    // what the centre lists.
    property list<Notif> list: []

    readonly property list<Notif> popups: list.filter(n => n.popup)

    // Do not disturb. Everything still lands in the centre, but only a
    // critical notification pops up over it.
    property bool dnd: false

    // Arrived since the centre was last opened.
    readonly property int unread: list.filter(n => !n.read).length

    // How long a popup stays up when the sender leaves it to the server.
    readonly property int defaultTimeout: 6000
    readonly property int criticalTimeout: 12000

    // Past this the oldest ones are dropped, so an app spamming the bus
    // cannot grow the centre without end.
    readonly property int maxHistory: 100

    // Fired as each notification arrives, for the bar's bell to ring.
    signal arrived(notif: Notif)

    function markAllRead(): void {
        for (const n of list)
            n.read = true;
    }

    function clearAll(): void {
        for (const n of [...list])
            n.dismiss();
    }

    function toggleDnd(): void {
        dnd = !dnd;
    }

    // Safe to call twice: a dismissal from here and the sender's closed
    // signal both end up in it.
    //
    // Not destroyed on the spot: whatever was showing it is still
    // animating it away, and would be left reading a dead object.
    function remove(notif: Notif): void {
        if (!list.includes(notif))
            return;
        list = list.filter(n => n !== notif);
        graveyard = [...graveyard, notif];
        reaper.restart();
    }

    property var graveyard: []

    Timer {
        id: reaper

        interval: 2000
        onTriggered: {
            for (const n of root.graveyard)
                n.destroy();
            root.graveyard = [];
        }
    }

    component Notif: QtObject {
        id: notif

        required property Notification notification

        // Copied out rather than bound, so a popup whose notification has
        // already gone away still has something to draw while it animates
        // out. sync() copies them again whenever the sender updates it.
        readonly property int nid: notification?.id ?? 0
        property string summary
        property string body
        property string appName
        property string appIcon
        property string image
        property int urgency: NotificationUrgency.Normal
        property var actions: []
        property int timeout: root.defaultTimeout
        property date time: new Date()

        function sync(): void {
            const n = notification;
            if (!n)
                return;
            summary = n.summary;
            body = n.body;
            appName = n.appName || qsTr("Unknown");
            appIcon = n.appIcon;
            image = n.image;
            urgency = n.urgency;
            // Only the labels: the action objects die with the
            // notification, and invoke() looks the live one up again.
            actions = n.actions.map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    }));

            // In milliseconds, as the sender gave it over D-Bus, and zero
            // or less for the server to decide.
            timeout = n.expireTimeout > 0 ? n.expireTimeout : urgency === NotificationUrgency.Critical ? root.criticalTimeout : root.defaultTimeout;
        }

        // Nothing counts down until the sender's timeout has been read:
        // a running animation does not pick up a new duration.
        property bool ready: false

        Component.onCompleted: {
            sync();
            left = timeout;
            ready = true;
            arm();
        }

        readonly property bool critical: urgency === NotificationUrgency.Critical

        // A named icon or a path, resolved to something an Image can show.
        readonly property string iconSource: {
            const icon = appIcon;
            if (icon === "")
                return "";
            if (icon.startsWith("/") || icon.includes("://"))
                return icon.startsWith("/") ? "file://" + icon : icon;
            return Quickshell.iconPath(icon, true);
        }

        property bool popup: false
        property bool read: false

        // How many popups on any screen have a pointer on them. The
        // countdown only runs while this is zero.
        property int holds: 0

        // Asked of whatever is showing the popup, which animates it away
        // and then calls hidePopup(). Split so the countdown ending does
        // not yank the toast off the screen mid-frame.
        signal timedOut

        function hold(holding: bool): void {
            holds = Math.max(0, holds + (holding ? 1 : -1));
        }

        function hidePopup(): void {
            popup = false;
            holds = 0;
        }

        // Only told to the sender while it is still in the list: once it
        // has closed -- by the sender, or by an action -- Quickshell keeps
        // the object around only for reading, and refuses to close it
        // again.
        function dismiss(): void {
            const n = notification;
            const live = root.list.includes(notif);
            popup = false;
            root.remove(notif);
            if (live)
                n?.dismiss();
        }

        // Set for the rest of the event that invoked an action. A tap on
        // a button also reaches the body behind it, whose handler would
        // fire the default action on top; the button comes first, being
        // on top, and this turns the body's second go away.
        property bool invoking: false

        // The default action is what a click on the body means. Resident
        // notifications stay after an action, as the spec asks; any other
        // Quickshell closes itself as it invokes the action, so only the
        // wrapper is left to put away here.
        function invoke(identifier: string): void {
            if (invoking || !root.list.includes(notif))
                return;
            const action = notification?.actions.find(a => a.identifier === identifier);
            if (!action)
                return;

            invoking = true;
            Qt.callLater(() => notif.invoking = false);

            const resident = notification?.resident ?? false;
            action.invoke();
            if (!resident) {
                popup = false;
                root.remove(notif);
            }
        }

        readonly property bool hasDefault: actions.some(a => a.identifier === "default")

        // Everything but the default action, which has no label worth a
        // button.
        readonly property var buttons: actions.filter(a => a.identifier !== "default")

        // The countdown itself is a timer against the clock. An animation
        // would do, but it only advances while some window is drawing, so
        // a popup that arrived behind a lock screen would never run out.
        property real left
        property real armedAt: 0

        function arm(): void {
            if (!ready || !popup || holds > 0 || expiry.running)
                return;
            armedAt = Date.now();
            expiry.interval = Math.max(1, left);
            expiry.start();
        }

        function disarm(): void {
            if (!expiry.running)
                return;
            left = Math.max(0, left - (Date.now() - armedAt));
            expiry.stop();
        }

        onPopupChanged: {
            expiry.stop();
            left = timeout;
            arm();
        }

        onHoldsChanged: holds > 0 ? disarm() : arm()

        property Timer expiry: Timer {
            onTriggered: notif.timedOut()
        }

        // How much of the time is left, 1 to 0, read off the same clock
        // the timer runs on. For the popup to sample each frame.
        function fraction(): real {
            const l = expiry.running ? left - (Date.now() - armedAt) : left;
            return Math.max(0, Math.min(1, l / Math.max(1, timeout)));
        }

        // The sender closing it, or it expiring by some other hand: the
        // wrapper goes with it.
        property Connections watcher: Connections {
            target: notif.notification

            function onClosed(): void {
                root.remove(notif);
            }

            function onSummaryChanged(): void {
                notif.sync();
            }

            function onBodyChanged(): void {
                notif.sync();
            }

            function onImageChanged(): void {
                notif.sync();
            }

            function onActionsChanged(): void {
                notif.sync();
            }
        }
    }

    Component {
        id: notifComponent

        Notif {}
    }

    function wrap(notification: Notification, popup: bool): Notif {
        return notifComponent.createObject(root, {
            notification,
            popup,
            read: !popup
        });
    }

    NotificationServer {
        id: server

        // Survive a reload of the shell: the notifications stay tracked
        // and are picked up again below instead of vanishing.
        keepOnReload: true
        persistenceSupported: true

        // Plain text only. The popups and the centre draw the body as
        // plain text, so markup would arrive as its tags.
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false

        onNotification: notification => {
            notification.tracked = true;

            // Carried over from before a reload: already seen once, so it
            // goes back in the centre without popping up again.
            if (notification.lastGeneration) {
                if (!root.list.some(n => n.notification === notification))
                    root.list = [root.wrap(notification, false), ...root.list];
                return;
            }

            const popup = !root.dnd || notification.urgency === NotificationUrgency.Critical;

            // A replacement for one already shown -- a progress update, a
            // chat piling up -- takes its place at the top rather than
            // stacking a second copy.
            const old = root.list.find(n => n.nid === notification.id);
            if (old && old.notification === notification) {
                old.sync();
                old.time = new Date();
                old.read = false;
                // Dropped and raised again, which restarts the countdown
                // without breaking its binding to the popup.
                old.popup = false;
                old.popup = popup;
                root.list = [old, ...root.list.filter(n => n !== old)];
                root.arrived(old);
                return;
            }
            if (old)
                root.remove(old);

            const notif = root.wrap(notification, popup);

            let next = [notif, ...root.list];
            while (next.length > root.maxHistory)
                next.pop().dismiss();
            root.list = next;

            root.arrived(notif);
        }
    }

    // What was still tracked across a reload comes back into the centre,
    // but not as popups: they were already seen once.
    Component.onCompleted: {
        const kept = server.trackedNotifications.values.filter(n => !list.some(w => w.notification === n)).map(n => root.wrap(n, false));
        list = [...list, ...kept.reverse()];
    }

    //   qs -p ~/morph-shell ipc call notifs toggleDnd
    IpcHandler {
        target: "notifs"

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clear(): void {
            root.clearAll();
        }
    }
}
