import QtQuick

QtObject {
    readonly property int height: 58

    // Inset from the screen edges while floating, as the bar is.
    readonly property int margin: 8

    // Strip at the very bottom edge that reveals the dock on hover,
    // running up to the dock's own edge so the pointer never falls
    // through a dead gap on its way there.
    readonly property int reveal: margin + 1

    readonly property int openDelay: 90
    readonly property int closeDelay: 220

    readonly property int iconSize: 38

    // Which applications sit in the dock, by desktop entry id -- the
    // .desktop file's name without the suffix. Exact ids are matched
    // first and near misses are looked up heuristically, so "code"
    // finds code-url-handler. An id nothing answers to is skipped
    // rather than drawn as a hole.
    readonly property var pinned: ["firefox", "kitty", "code", "spotify", "org.gnome.Nautilus", "discord-canary"]

    // What the dock grows into. The width is the panel's; the height
    // is everything above the pinned row, which stays put.
    readonly property int launcherWidth: 520
    readonly property int resultHeight: 48
    readonly property int maxResults: 7

    // Derived rather than picked, so the panel always ends on a whole
    // row. A height chosen by eye leaves a row sliced through the
    // middle at the bottom edge, which reads as the list being cut
    // off rather than as more of it being below.
    //
    // Top padding, the search field, the gap under it, the rows and
    // the gaps between them, and a breath before the pinned icons.
    readonly property int launcherHeight: 16 + resultHeight + 8 + maxResults * resultHeight + (maxResults - 1) * 4 + 8

    // The clipboard panel grows to the same shape, so the dock can
    // turn from one into the other without changing size. An image
    // takes up two rows and the gap between them, which keeps the
    // panel ending on whole rows however text and images mix.
    readonly property int imageResultHeight: resultHeight * 2 + 4
    readonly property int thumbnailMaxWidth: 168

    // One dot under a pinned icon for each of its windows, up to
    // this many: past it the count stops being read at a glance.
    readonly property int maxDots: 4

    // The window chooser: a card per window, a live picture of it
    // over its title, so many to a row and so many rows before it
    // scrolls. A picture is 16:9 of the card's width, which is what
    // two columns leave of the panel.
    readonly property int chooserColumns: 2
    readonly property int chooserRows: 2
    readonly property int previewHeight: 135
    readonly property int cardTitleHeight: 32
}
