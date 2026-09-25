import QtQuick
import qs.components
import qs.config
import qs.services

// Just the bar widget. The panel it opens lives in ClockPopup, declared
// before the bar surface so it slides out from behind it.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    implicitWidth: label.implicitWidth + Appearance.padding.large * 2
    implicitHeight: label.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    StyledText {
        id: label

        anchors.centerIn: parent

        animate: true
        text: Time.format("hh:mm")
    }
}
