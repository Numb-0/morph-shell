import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: play state and the current track, opening the media panel
// on click exactly as the clock does.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    // The title is given a fixed box rather than being sized to the text.
    // The widget is the media panel's anchor, and the panel centres on it,
    // so a widget that resized with the track would drag the open panel
    // sideways on every song change.
    readonly property int titleWidth: 180

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            icon: Players.playing ? "pause" : "play_arrow"
            size: Appearance.font.icon.normal
            color: Appearance.palette.primary

            // Solid, as the drawn transport icons were. An outlined
            // triangle at this size reads as a hollow arrow rather than
            // as a play button.
            fill: 1
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            animate: true
            // Kept in the bar with nothing playing, so the widget
            // stays where you expect it rather than appearing and
            // shifting the row about.
            text: Players.active?.trackTitle || qsTr("Nothing playing")
            color: Players.available ? Appearance.palette.text : Appearance.palette.subtext
            elide: Text.ElideRight
            width: root.titleWidth
        }
    }
}
