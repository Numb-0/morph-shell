pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// chromix, as the theme panel wants it: the themes Nix built, which one
// is up and in which mode, and a way to switch.
//
// Reads chromix's own files rather than asking the CLI, so the panel
// follows a switch made from a terminal or a keybind too. Switching
// goes through the CLI, which relinks every app and reloads them.
//
// chromix reloads this shell through the installed `morph-shell`
// wrapper, which misses a shell run from a checkout. So the palette is
// also reloaded here whenever chromix's state changes, from wherever
// the switch was made.
Singleton {
    id: root

    readonly property string manifestPath: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/chromix/manifest.json`
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/chromix/state.json`

    // Without a manifest there is no chromix to drive, and the widget is
    // not drawn.
    readonly property bool available: themes.length > 0

    // Every declared theme, in the order chromix lists them, as
    // { name, dark, light }: the rendered directory for each mode.
    property var themes: []

    // What is up now. Before chromix has ever run, the manifest's
    // default -- the same fallback the CLI uses.
    property string theme: ""
    property string mode: "dark"
    property string defaultTheme: ""
    property string defaultMode: "dark"

    readonly property bool dark: mode !== "light"

    // A switch is in flight: chromix relinking and reloading every app,
    // which takes a moment.
    readonly property bool busy: proc.running

    // What was asked for last, so the panel can mark it before chromix
    // has written it back.
    property string requested: ""

    // Every switch asked for has gone through, or failed: the queue has
    // run dry and chromix has reloaded what it reloads. `ok` is whether
    // the last of them went through.
    signal finished(bool ok)

    // The rendered directory for a theme, in the current mode or the
    // one given.
    function dirFor(name: string, inMode: string): string {
        const t = themes.find(t => t.name === name);
        if (!t)
            return "";
        return (inMode || mode) === "light" ? t.light : t.dark;
    }

    // Switches to a theme, and to a mode with it if one is given, in one
    // go rather than two relinks.
    function set(name: string, inMode: string): void {
        const toMode = inMode || mode;
        if (name === theme && toMode === mode && !busy)
            return;
        requested = name;
        run(inMode ? ["chromix", "set", name, inMode] : ["chromix", "set", name]);
    }

    function setMode(value: string): void {
        run(["chromix", "mode", value]);
    }

    function toggleMode(): void {
        setMode(dark ? "light" : "dark");
    }

    // One switch at a time. A click landing while one runs replaces
    // whatever was queued behind it, so a flurry of clicks settles on
    // the last one rather than playing each out in turn.
    property var queued: null

    function run(command: var): void {
        if (proc.running) {
            queued = command;
            return;
        }
        proc.command = command;
        proc.running = true;
    }

    Process {
        id: proc

        stderr: StdioCollector {
            id: errors
        }

        onExited: code => {
            if (code !== 0)
                console.warn(`themes: ${proc.command.join(" ")}: ${errors.text.trim()}`);

            if (root.queued) {
                const next = root.queued;
                root.queued = null;
                root.run(next);
            } else {
                root.requested = "";
                root.finished(code === 0);
            }
        }
    }

    FileView {
        path: root.manifestPath

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                const manifest = JSON.parse(text());
                root.themes = Object.keys(manifest.themes ?? {}).sort().map(name => ({
                            name,
                            dark: manifest.themes[name].dark ?? "",
                            light: manifest.themes[name].light ?? ""
                        }));
                root.defaultTheme = manifest.default?.theme ?? "";
                root.defaultMode = manifest.default?.mode ?? "dark";
                if (!stateFile.loaded) {
                    root.theme = root.defaultTheme;
                    root.mode = root.defaultMode;
                }
            } catch (e) {
                console.warn(`themes: ${root.manifestPath}: ${e}`);
            }
        }

        // No chromix is a normal state, not an error.
        printErrors: false
        onLoadFailed: root.themes = []
    }

    // Rewritten on every switch, from wherever it was made.
    FileView {
        id: stateFile

        property bool loaded: false

        path: root.statePath

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.theme = state.theme ?? root.defaultTheme;
                root.mode = state.mode ?? root.defaultMode;

                // The first read is the shell starting up, which has
                // its colours already.
                if (loaded)
                    Colours.reload();
                loaded = true;
            } catch (e) {
                // Caught mid-write: the next change brings the rest.
            }
        }

        printErrors: false
    }
}
