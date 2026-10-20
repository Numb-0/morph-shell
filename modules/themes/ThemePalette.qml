import QtQuick
import qs.components
import qs.config

// The roles the theme window draws with, taken from whichever theme is
// being looked at rather than the one that is up, so the window wears a
// theme before it is applied. Named as Colours.palette names them, and
// falling back on it for any role a theme leaves out.
//
// Each role fades on its own as the theme under the pointer changes,
// which Colours does with one shared progress instead: that suits a
// palette that changes rarely and all at once, while this one is swept
// across tile by tile, and a fade caught midway has to carry on from
// wherever each role has got to.
QtObject {
    id: root

    // A theme's colors.json, parsed. Empty for the shell's own.
    property var roles: ({})

    function pick(name: string, fallback: color): color {
        return roles[name] ?? fallback;
    }

    property color m3surface: pick("surface", Colours.palette.m3surface)
    property color m3surfaceContainer: pick("surfaceContainer", Colours.palette.m3surfaceContainer)
    property color m3surfaceContainerHigh: pick("surfaceContainerHigh", Colours.palette.m3surfaceContainerHigh)
    property color m3surfaceContainerHighest: pick("surfaceContainerHighest", Colours.palette.m3surfaceContainerHighest)
    property color m3onSurface: pick("onSurface", Colours.palette.m3onSurface)
    property color m3onSurfaceVariant: pick("onSurfaceVariant", Colours.palette.m3onSurfaceVariant)
    property color m3outline: pick("outline", Colours.palette.m3outline)
    property color m3outlineVariant: pick("outlineVariant", Colours.palette.m3outlineVariant)
    property color m3scrim: pick("scrim", Colours.palette.m3scrim)
    property color m3primary: pick("primary", Colours.palette.m3primary)
    property color m3onPrimary: pick("onPrimary", Colours.palette.m3onPrimary)
    property color m3primaryContainer: pick("primaryContainer", Colours.palette.m3primaryContainer)
    property color m3onPrimaryContainer: pick("onPrimaryContainer", Colours.palette.m3onPrimaryContainer)
    property color m3secondary: pick("secondary", Colours.palette.m3secondary)
    property color m3secondaryContainer: pick("secondaryContainer", Colours.palette.m3secondaryContainer)
    property color m3onSecondaryContainer: pick("onSecondaryContainer", Colours.palette.m3onSecondaryContainer)
    property color m3tertiary: pick("tertiary", Colours.palette.m3tertiary)
    property color m3tertiaryContainer: pick("tertiaryContainer", Colours.palette.m3tertiaryContainer)
    property color m3error: pick("error", Colours.palette.m3error)

    Behavior on m3surface {
        CAnim {}
    }
    Behavior on m3surfaceContainer {
        CAnim {}
    }
    Behavior on m3surfaceContainerHigh {
        CAnim {}
    }
    Behavior on m3surfaceContainerHighest {
        CAnim {}
    }
    Behavior on m3onSurface {
        CAnim {}
    }
    Behavior on m3onSurfaceVariant {
        CAnim {}
    }
    Behavior on m3outline {
        CAnim {}
    }
    Behavior on m3outlineVariant {
        CAnim {}
    }
    Behavior on m3scrim {
        CAnim {}
    }
    Behavior on m3primary {
        CAnim {}
    }
    Behavior on m3onPrimary {
        CAnim {}
    }
    Behavior on m3primaryContainer {
        CAnim {}
    }
    Behavior on m3onPrimaryContainer {
        CAnim {}
    }
    Behavior on m3secondary {
        CAnim {}
    }
    Behavior on m3secondaryContainer {
        CAnim {}
    }
    Behavior on m3onSecondaryContainer {
        CAnim {}
    }
    Behavior on m3tertiary {
        CAnim {}
    }
    Behavior on m3tertiaryContainer {
        CAnim {}
    }
    Behavior on m3error {
        CAnim {}
    }
}
