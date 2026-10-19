import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The battery's panel: the charge, what it is doing, and how long that
// leaves. Everything about how it grows out of the bar lives in
// BlobPopup.
BlobPopup {
    id: root

    // The same tinting the bar widget uses, so the glyph does not change
    // colour as the panel opens under it.
    readonly property color accent: Power.critical ? Appearance.palette.m3error : Power.low ? Appearance.palette.m3warning : Power.charging ? Appearance.palette.m3success : Appearance.palette.m3onSurface

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.small

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter

                icon: Power.icon
                size: Appearance.font.icon.large
                color: root.accent
                fill: Power.low || Power.charging ? 1 : 0
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter

                text: Math.round(Power.percentage * 100) + "%"
                font.pixelSize: Appearance.font.large
                color: root.accent
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            animate: true
            text: Power.status
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            // Nothing honest to say until UPower has a rate to work
            // from, so the line goes away rather than reading 0m.
            visible: Power.timeRemaining > 0

            animate: true
            text: Power.charging ? qsTr("%1 until full").arg(Power.formatTime(Power.timeRemaining)) : qsTr("%1 remaining").arg(Power.formatTime(Power.timeRemaining))
            color: Appearance.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            visible: Power.healthSupported

            text: qsTr("Health %1%").arg(Math.round(Power.health * 100))
            color: Appearance.palette.m3onSurfaceVariant
        }
    }
}
