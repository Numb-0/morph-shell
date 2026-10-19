import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the joined network's name and the link's glyph. Click
// opens the network panel, middle click switches Wi-Fi on or off
// without opening anything.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    // Past this the name is cut short rather than pushing the rest of
    // the bar along; the panel has room for all of it.
    readonly property int maxLabelWidth: 140

    implicitWidth: row.implicitWidth + Appearance.bar.itemPadding * 2
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            glyph.press();
            root.clicked();
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        onTapped: {
            glyph.press();
            Net.setWifiEnabled(!Net.wifiEnabled);
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        // Wi-Fi only, and only while joined. A cable has no name worth
        // reading, and its glyph already says what it is.
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: text !== ""
            width: Math.min(implicitWidth, root.maxLabelWidth)

            animate: true
            text: Net.ethernet ? "" : Net.active?.name ?? ""
            elide: Text.ElideRight
        }

        MaterialSymbol {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter

            icon: Net.icon
            size: Appearance.font.icon.normal

            // Dimmed while there is no link at all, so an unplugged machine
            // reads at a glance -- as a muted output does.
            color: Net.connected ? Appearance.palette.m3onSurface : Appearance.palette.m3onSurfaceVariant

            // Solid while connected: the fan filled up to its signal.
            fill: Net.connected ? 1 : 0
        }
    }
}
