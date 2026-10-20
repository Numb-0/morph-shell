import QtQuick

QtObject {
    required property BarConfig bar

    readonly property int width: 380

    // Below where the bar rests, so the bar sliding in never lands on
    // a popup.
    readonly property int top: bar.margin + bar.height + 12
    readonly property int margin: bar.margin

    // Room between stacked popups. Kept wider than the smoothing so
    // neighbours at rest stay apart, and only fuse while one is
    // moving through another.
    readonly property int gap: 18
    readonly property int smoothing: 14

    // The droplet a popup is born as and dies back into.
    readonly property int drop: 34

    // More than this at once and the oldest wait in the centre.
    readonly property int maxPopups: 4

    // The panel in the bar, and how far down the screen its list may
    // run before it scrolls.
    readonly property int panelWidth: 380
    readonly property int panelHeight: 460
}
