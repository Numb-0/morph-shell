pragma Singleton

import QtQuick
import Quickshell
import Morph.Search

// What the launcher runs when a search starts with ":": the shell's own
// actions, by name, rather than applications. Typing the colon alone
// lists them all, so they can be found without knowing them first.
//
// A command either opens one of the dock's other panels -- `panel`
// names it, and the dock does the switching -- or does something and
// lets the launcher close, through `run`.
Singleton {
    id: root

    readonly property string prefix: ":"

    // Lock, screenshot and the colour picker live in modules of their
    // own rather than in a service, so they are asked through these
    // instead of called.
    signal lockRequested
    signal screenshotRequested
    signal colorPickerRequested
    signal overviewRequested

    // In the order they are listed under a bare colon: the panels first,
    // then the rest by how often they are likely to be wanted.
    //
    // Rebuilt when do not disturb flips, so its row says what it would
    // do rather than what it did last time.
    readonly property var all: [
        {
            name: "cliphist",
            description: qsTr("Clipboard history"),
            icon: "content_paste",
            panel: "clipboard",
            available: Clipboard.available
        },
        {
            name: "overview",
            description: qsTr("Every workspace and its windows"),
            icon: "grid_view",
            run: () => root.overviewRequested(),
            available: true
        },
        {
            name: "screenshot",
            description: qsTr("Screenshot a region"),
            icon: "screenshot_region",
            run: () => root.screenshotRequested(),
            available: true
        },
        {
            name: "colorpicker",
            description: qsTr("Pick a colour from the screen"),
            icon: "colorize",
            run: () => root.colorPickerRequested(),
            available: true
        },
        {
            name: "lock",
            description: qsTr("Lock the session"),
            icon: "lock",
            run: () => root.lockRequested(),
            available: true
        },
        {
            name: "session",
            description: qsTr("Log out, restart or shut down"),
            icon: "power_settings_new",
            run: () => BarState.panelToggled("session"),
            available: true
        },
        {
            name: "dnd",
            description: Notifs.dnd ? qsTr("Turn do not disturb off") : qsTr("Turn do not disturb on"),
            icon: Notifs.dnd ? "notifications_active" : "do_not_disturb_on",
            run: () => Notifs.toggleDnd(),
            available: true
        },
        {
            name: "clear",
            description: qsTr("Dismiss every notification"),
            icon: "clear_all",
            run: () => Notifs.clearAll(),
            available: true
        }
    ].filter(c => c.available)

    // Whether a search is one for commands at all.
    function matches(query: string): bool {
        return (query ?? "").replace(/^\s+/, "").startsWith(prefix);
    }

    // The command a search names exactly, colon and all, or null.
    function exact(query: string): var {
        if (!matches(query))
            return null;

        const name = (query ?? "").trim().slice(prefix.length).toLowerCase();
        return all.find(c => c.name === name) ?? null;
    }

    // Names are short and few, so a name that starts with what was typed
    // goes first and one that only contains it next. The fuzzy match is
    // held back until there are a few letters to go on: one or two match
    // something in nearly every name and description, and ":s" would
    // list everything rather than screenshot and session.
    readonly property int fuzzyFrom: 3

    function score(command: var, typed: string): real {
        if (command.name.startsWith(typed))
            return 3;
        if (command.name.includes(typed))
            return 2;
        if (typed.length < fuzzyFrom)
            return 0;

        return Math.max(Fuzzy.score(typed, command.name), Fuzzy.score(typed, command.description.toLowerCase()) * Apps.metadataWeight);
    }

    function search(query: string): var {
        const typed = (query ?? "").trim().slice(prefix.length).trim().toLowerCase();
        if (typed.length === 0)
            return all;

        return all.map(command => ({
                command,
                score: score(command, typed)
            })).filter(r => r.score >= Apps.threshold).sort((a, b) => b.score - a.score).map(r => r.command);
    }
}
