import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The clock's panel: just the content. Everything about how it grows out
// of the bar lives in BlobPopup.
BlobPopup {
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            text: Time.format("dddd")
            font.pixelSize: Appearance.font.large
            color: Appearance.palette.primary
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            text: Time.format("dd MMMM yyyy")
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter

            // Deliberately not animated: this changes every second, and
            // the fade would read as a flicker.
            text: Time.format("hh:mm:ss")
            color: Appearance.palette.subtext
        }
    }
}
