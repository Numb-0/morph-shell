import QtQuick

QtObject {
    readonly property int height: 34

    // Inset from the screen edges while floating.
    readonly property int margin: 8

    // Space either side of each widget's content. Neighbours touch,
    // so this is also half the gap between them -- and the hover and
    // click target reaches this far past the glyph.
    readonly property int itemPadding: 8

    // Strip at the very top edge that reveals the bar on hover. Runs
    // down to the bar's top edge so the pointer never falls through a
    // dead gap on its way there.
    readonly property int reveal: margin + 1

    // Dwell before revealing, so a cursor sweeping past the screen
    // edge does not flash the bar open, and a grace period before
    // retracting so brushing just outside does not snap it shut.
    readonly property int openDelay: 90
    readonly property int closeDelay: 220

    readonly property QtObject workspaces: QtObject {
        // Slots always drawn; the row grows past this to reach the
        // highest workspace in use rather than hiding it.
        readonly property int shown: 5

        // How the indicator draws itself: "drop" (a drop that leaps
        // from slot to slot and splashes down), "fluid" (a pool of
        // liquid poured from slot to slot), "constellation"
        // (workspaces in use as linked stars, the active one a comet)
        // or "shapes" (the active one a Material shape that morphs
        // into the next workspace's).
        readonly property string style: "shapes"
    }
}
