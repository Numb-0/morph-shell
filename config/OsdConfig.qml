import QtQuick

QtObject {
    required property DockConfig dock

    // How long the volume OSD stays up after the level last moved.
    readonly property int timeout: 1500

    // Distance from the bottom edge. Clears the dock, revealed or
    // not, so the two never sit on top of each other.
    readonly property int margin: dock.margin + dock.height + 12
}
