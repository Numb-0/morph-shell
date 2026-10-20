pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette the shell draws in, read from a file a theme switcher
// swaps, and faded to whenever it changes.
Singleton {
    id: root

    // Where the colours come from. A theme switcher swaps this file (or
    // what it links to) and the shell follows; with no file the defaults
    // below stand.
    readonly property string colorsPath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/morph-shell/colors.json`

    // The full Material 3 role set, named as material-color-utilities
    // names them behind an m3 prefix: QML reads a property called
    // onSurface as a handler for a surface signal, so the bare names
    // cannot be declared.
    //
    // A theme change fades every role at once rather than cutting, so it
    // washes over the whole shell and no widget needs a colour animation
    // of its own for it.
    readonly property QtObject palette: QtObject {
        // Seed hues the scheme was generated from. For tooling more than for
        // drawing.
        readonly property color m3primaryPaletteKeyColor: root.role("primaryPaletteKeyColor")
        readonly property color m3secondaryPaletteKeyColor: root.role("secondaryPaletteKeyColor")
        readonly property color m3tertiaryPaletteKeyColor: root.role("tertiaryPaletteKeyColor")
        readonly property color m3neutralPaletteKeyColor: root.role("neutralPaletteKeyColor")
        readonly property color m3neutralVariantPaletteKeyColor: root.role("neutralVariantPaletteKeyColor")

        // Surfaces, dimmest to brightest. Panels sit on surfaceContainer;
        // wells and cards inset into a panel drop back to surface, cards
        // raised on one step up to the High containers. background is the
        // older name for surface and kept only because schemes carry it.
        readonly property color m3background: root.role("background")
        readonly property color m3onBackground: root.role("onBackground")
        readonly property color m3surface: root.role("surface")
        readonly property color m3surfaceDim: root.role("surfaceDim")
        readonly property color m3surfaceBright: root.role("surfaceBright")
        readonly property color m3surfaceContainerLowest: root.role("surfaceContainerLowest")
        readonly property color m3surfaceContainerLow: root.role("surfaceContainerLow")
        readonly property color m3surfaceContainer: root.role("surfaceContainer")
        readonly property color m3surfaceContainerHigh: root.role("surfaceContainerHigh")
        readonly property color m3surfaceContainerHighest: root.role("surfaceContainerHighest")

        // Content on any surface: body text, then the quieter secondary text
        // and inactive glyphs.
        readonly property color m3onSurface: root.role("onSurface")
        readonly property color m3surfaceVariant: root.role("surfaceVariant")
        readonly property color m3onSurfaceVariant: root.role("onSurfaceVariant")

        // For what stands out against the theme itself: tooltips, snackbars.
        readonly property color m3inverseSurface: root.role("inverseSurface")
        readonly property color m3inverseOnSurface: root.role("inverseOnSurface")
        readonly property color m3inversePrimary: root.role("inversePrimary")

        // Borders and the off state of controls -- the unchecked switch, an
        // unfocused field -- then the fainter divider.
        readonly property color m3outline: root.role("outline")
        readonly property color m3outlineVariant: root.role("outlineVariant")

        // Behind things: drop shadows, the dim under a modal, and the tint an
        // elevated surface takes on.
        readonly property color m3shadow: root.role("shadow")
        readonly property color m3scrim: root.role("scrim")
        readonly property color m3surfaceTint: root.role("surfaceTint")

        // Accents. The plain role is the strong one, for small fills like a
        // button or the active track of a slider; the container is the
        // softer tone for larger areas like a selected chip.
        readonly property color m3primary: root.role("primary")
        readonly property color m3onPrimary: root.role("onPrimary")
        readonly property color m3primaryContainer: root.role("primaryContainer")
        readonly property color m3onPrimaryContainer: root.role("onPrimaryContainer")
        readonly property color m3secondary: root.role("secondary")
        readonly property color m3onSecondary: root.role("onSecondary")
        readonly property color m3secondaryContainer: root.role("secondaryContainer")
        readonly property color m3onSecondaryContainer: root.role("onSecondaryContainer")
        readonly property color m3tertiary: root.role("tertiary")
        readonly property color m3onTertiary: root.role("onTertiary")
        readonly property color m3tertiaryContainer: root.role("tertiaryContainer")
        readonly property color m3onTertiaryContainer: root.role("onTertiaryContainer")

        // States. Warning and error carry the battery as it drains; success
        // calls out charging. Material has no success or warning role, so a
        // theme supplies them as custom colours -- matugen harmonises them
        // towards primary.
        readonly property color m3error: root.role("error")
        readonly property color m3onError: root.role("onError")
        readonly property color m3errorContainer: root.role("errorContainer")
        readonly property color m3onErrorContainer: root.role("onErrorContainer")
        readonly property color m3success: root.role("success")
        readonly property color m3onSuccess: root.role("onSuccess")
        readonly property color m3successContainer: root.role("successContainer")
        readonly property color m3onSuccessContainer: root.role("onSuccessContainer")
        readonly property color m3warning: root.role("warning")
        readonly property color m3onWarning: root.role("onWarning")
        readonly property color m3warningContainer: root.role("warningContainer")
        readonly property color m3onWarningContainer: root.role("onWarningContainer")

        // Accents that hold the same tone in light and dark mode.
        readonly property color m3primaryFixed: root.role("primaryFixed")
        readonly property color m3primaryFixedDim: root.role("primaryFixedDim")
        readonly property color m3onPrimaryFixed: root.role("onPrimaryFixed")
        readonly property color m3onPrimaryFixedVariant: root.role("onPrimaryFixedVariant")
        readonly property color m3secondaryFixed: root.role("secondaryFixed")
        readonly property color m3secondaryFixedDim: root.role("secondaryFixedDim")
        readonly property color m3onSecondaryFixed: root.role("onSecondaryFixed")
        readonly property color m3onSecondaryFixedVariant: root.role("onSecondaryFixedVariant")
        readonly property color m3tertiaryFixed: root.role("tertiaryFixed")
        readonly property color m3tertiaryFixedDim: root.role("tertiaryFixedDim")
        readonly property color m3onTertiaryFixed: root.role("onTertiaryFixed")
        readonly property color m3onTertiaryFixedVariant: root.role("onTertiaryFixedVariant")
    }

    // What the shell shows with no colours file, and for any role a file
    // leaves out: Catppuccin Mocha, with the roles it has no colour for
    // mixed from the ones it does.
    readonly property var defaults: ({
        primaryPaletteKeyColor: "#89b4fa",
        secondaryPaletteKeyColor: "#b4befe",
        tertiaryPaletteKeyColor: "#cba6f7",
        neutralPaletteKeyColor: "#6c7086",
        neutralVariantPaletteKeyColor: "#7f849c",
        background: "#1e1e2e",
        onBackground: "#cdd6f4",
        surface: "#1e1e2e",
        surfaceDim: "#181825",
        surfaceBright: "#45475a",
        surfaceContainerLowest: "#11111b",
        surfaceContainerLow: "#181825",
        surfaceContainer: "#313244",
        surfaceContainerHigh: "#45475a",
        surfaceContainerHighest: "#585b70",
        onSurface: "#cdd6f4",
        surfaceVariant: "#45475a",
        onSurfaceVariant: "#bac2de",
        inverseSurface: "#cdd6f4",
        inverseOnSurface: "#1e1e2e",
        inversePrimary: "#5e78a8",
        outline: "#6c7086",
        outlineVariant: "#45475a",
        shadow: "#000000",
        scrim: "#000000",
        surfaceTint: "#89b4fa",
        primary: "#89b4fa",
        onPrimary: "#1e1e2e",
        primaryContainer: "#3e4b6b",
        onPrimaryContainer: "#bed6fc",
        secondary: "#b4befe",
        onSecondary: "#1e1e2e",
        secondaryContainer: "#4b4e6c",
        onSecondaryContainer: "#d6dbfe",
        tertiary: "#cba6f7",
        onTertiary: "#1e1e2e",
        tertiaryContainer: "#52476a",
        onTertiaryContainer: "#e2cefb",
        error: "#f38ba8",
        onError: "#1e1e2e",
        errorContainer: "#5e3f53",
        onErrorContainer: "#f8bfcf",
        success: "#a6e3a1",
        onSuccess: "#1e1e2e",
        successContainer: "#475950",
        onSuccessContainer: "#cef0cb",
        warning: "#f9e2af",
        onWarning: "#1e1e2e",
        warningContainer: "#605955",
        onWarningContainer: "#fcefd3",
        primaryFixed: "#caddfd",
        primaryFixedDim: "#89b4fa",
        onPrimaryFixed: "#11111b",
        onPrimaryFixedVariant: "#495a80",
        secondaryFixed: "#dde2ff",
        secondaryFixedDim: "#b4befe",
        onSecondaryFixed: "#11111b",
        onSecondaryFixedVariant: "#5a5e81",
        tertiaryFixed: "#e8d7fb",
        tertiaryFixedDim: "#cba6f7",
        onTertiaryFixed: "#11111b",
        onTertiaryFixedVariant: "#63547e"
    })

    // A theme change is a fade from one full set of roles to another,
    // driven by one shared progress rather than an animation per role.
    property var fromRoles: parse(defaults)
    property var toRoles: parse(defaults)
    property real progress: 1

    function parse(roles: var): var {
        const out = {};
        for (const name in defaults)
            out[name] = Qt.darker(roles[name] ?? defaults[name], 1);
        return out;
    }

    function role(name: string): color {
        const a = fromRoles[name];
        const b = toRoles[name];
        return Qt.rgba(a.r + (b.r - a.r) * progress, a.g + (b.g - a.g) * progress, a.b + (b.b - a.b) * progress, a.a + (b.a - a.a) * progress);
    }

    // Starts from what is on screen, so a change landing mid-fade carries
    // on from there instead of jumping.
    function fadeTo(roles: var): void {
        const current = {};
        for (const name in defaults)
            current[name] = palette["m3" + name];
        fromRoles = current;
        toRoles = parse(roles);
        fade.restart();
    }

    NumberAnimation {
        id: fade

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Appearance.anim.durations.slowEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.slowEffects
    }

    // The file names roles as M3 does, camelCase or snake_case (matugen
    // writes on_surface); keys it does not know are ignored.
    //
    //   { "primary": "#a8c8ff", "onPrimary": "#07305f", "surface": "#111318", ... }
    function load(text: string): void {
        try {
            const roles = {};
            const parsed = JSON.parse(text);
            for (const key in parsed)
                roles[key.replace(/_(\w)/g, (_, c) => c.toUpperCase())] = parsed[key];
            fadeTo(roles);
        } catch (e) {
            // Mid-write or malformed: keep the colours already up rather
            // than flashing back to the defaults.
            console.warn(`palette: ${colorsPath}: ${e}`);
        }
    }

    FileView {
        id: colorsFile

        path: root.colorsPath

        // Picks up the file being edited or replaced, and this path's own
        // symlink being repointed -- but not a link further up the chain
        // moving, which is how chromix switches. A switcher calls the
        // reload below after swapping.
        watchChanges: true
        onFileChanged: reload()

        onLoaded: root.load(text())

        // No file is a normal state -- the defaults apply -- not an error.
        printErrors: false
        onLoadFailed: root.fadeTo({})
    }

    // Re-reads the colours and wallpaper files, for a switcher that
    // repoints a link the watches cannot see.
    function reload(): void {
        colorsFile.reload();
        Wallpaper.reload();
    }

    //   qs -p ~/morph-shell ipc call palette reload
    IpcHandler {
        target: "palette"

        function reload(): void {
            root.reload();
        }
    }
}
