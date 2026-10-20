import QtQuick

QtObject {
    // The workspaces in use, read left to right and top down, at
    // most this many to a row. Cells are sized for a grid of
    // columns by rows, so a few workspaces make a small grid rather
    // than big cells; more than fit add rows.
    readonly property int rows: 2
    readonly property int columns: 5

    // The most of the screen the grid may take, across and down. A
    // cell keeps its screen's shape, so one of the two is usually
    // the limit and the other has room to spare.
    readonly property real maxWidth: 0.86
    readonly property real maxHeight: 0.62
}
