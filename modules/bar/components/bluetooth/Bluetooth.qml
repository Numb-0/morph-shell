import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: the connected device's name and the radio's glyph. Click
// opens the Bluetooth panel, middle click switches the radio on or off
// without opening anything.
Item {
    id: root

    signal clicked

    readonly property bool hovered: hover.hovered

    // Past this the name is cut short, as the network's is.
    readonly property int maxLabelWidth: 120

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
            Bt.setEnabled(!Bt.enabled);
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        // The one device connected, or how many when there are more:
        // two names would take half the bar.
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: text !== ""
            width: Math.min(implicitWidth, root.maxLabelWidth)

            animate: true
            text: Bt.connectedDevices.length === 1 ? Bt.connectedDevices[0].name : Bt.connectedDevices.length > 1 ? qsTr("%1 devices").arg(Bt.connectedDevices.length) : ""
            elide: Text.ElideRight
        }

        MaterialSymbol {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter

            icon: Bt.icon
            size: Appearance.font.icon.normal

            // Dimmed while off, as the network's is without a link.
            color: Bt.enabled ? Appearance.palette.m3onSurface : Appearance.palette.m3onSurfaceVariant

            // Solid while something is connected.
            fill: Bt.connected ? 1 : 0
        }
    }
}
