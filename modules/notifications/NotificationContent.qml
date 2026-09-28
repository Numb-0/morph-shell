import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// What a notification says, laid out the same way in a popup and in the
// centre: who sent it and when, the summary, the body, a picture if it
// brought one, and its actions as a row of tonal chips.
ColumnLayout {
    id: root

    required property var notif

    // Lines of body before it is cut short.
    property int bodyLines: 3

    // Shown at the header's end on hover, rather than at rest, so the
    // header reads as a line of text rather than a toolbar.
    property bool showClose: false

    signal closeRequested

    spacing: Appearance.spacing.small

    readonly property color accent: notif.critical ? Appearance.palette.m3error : Appearance.palette.m3primary

    // Minutes, then hours, then the date: fine grained while it is fresh,
    // and nobody needs the minute of something from last week.
    function ago(time: date): string {
        const s = Math.max(0, (Time.now - time) / 1000);
        if (s < 60)
            return qsTr("now");
        if (s < 3600)
            return qsTr("%1m").arg(Math.floor(s / 60));
        if (s < 86400)
            return qsTr("%1h").arg(Math.floor(s / 3600));
        return Qt.formatDate(time, "d MMM");
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        // The app's own icon when it has one, a tinted glyph otherwise.
        Item {
            implicitWidth: 20
            implicitHeight: 20

            Image {
                id: appIcon

                anchors.fill: parent

                visible: status === Image.Ready
                source: root.notif.iconSource
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            MaterialSymbol {
                anchors.centerIn: parent

                visible: !appIcon.visible

                icon: root.notif.critical ? "priority_high" : "notifications"
                size: Appearance.font.icon.small
                color: root.accent
                fill: 1
            }
        }

        StyledText {
            Layout.fillWidth: true

            text: root.notif.appName
            color: Appearance.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }

        StyledText {
            visible: !root.showClose

            text: root.ago(root.notif.time)
            color: Appearance.palette.m3onSurfaceVariant
        }

        // Swapped in over the time rather than beside it, so the header
        // does not reflow under the pointer.
        Item {
            visible: root.showClose

            implicitWidth: 20
            implicitHeight: 20

            HoverHandler {
                id: closeHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.closeRequested()
            }

            Rectangle {
                anchors.centerIn: parent

                width: 28
                height: 28
                radius: 14
                color: Appearance.palette.m3onSurface
                opacity: closeHover.hovered ? 0.12 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent

                icon: "close"
                size: Appearance.font.icon.small
                color: Appearance.palette.m3onSurfaceVariant
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            StyledText {
                Layout.fillWidth: true

                visible: text !== ""

                text: root.notif.summary
                font.pixelSize: Appearance.font.normal
                font.weight: Font.Medium
                color: root.notif.critical ? Appearance.palette.m3error : Appearance.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                visible: text !== ""

                text: root.notif.body
                color: Appearance.palette.m3onSurfaceVariant
                wrapMode: Text.Wrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
            }
        }

        // A sender's picture -- an avatar, album art -- in a rounded well.
        Rectangle {
            Layout.alignment: Qt.AlignTop

            visible: picture.status === Image.Ready

            implicitWidth: 48
            implicitHeight: 48
            radius: Appearance.rounding.medium
            color: Appearance.palette.m3surfaceContainerHighest
            clip: true

            Image {
                id: picture

                anchors.fill: parent

                source: root.notif.image
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    Flow {
        Layout.fillWidth: true

        visible: root.notif.buttons.length > 0
        spacing: Appearance.spacing.small

        Repeater {
            model: root.notif.buttons

            Rectangle {
                id: chip

                required property var modelData

                implicitWidth: chipLabel.implicitWidth + Appearance.padding.large * 2
                implicitHeight: 30

                radius: height / 2
                color: chipHover.hovered ? Appearance.palette.m3secondaryContainer : Appearance.palette.m3surfaceContainerHighest

                Behavior on color {
                    CAnim {}
                }

                HoverHandler {
                    id: chipHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.notif.invoke(chip.modelData.identifier)
                }

                StyledText {
                    id: chipLabel

                    anchors.centerIn: parent

                    text: chip.modelData.text
                    color: chipHover.hovered ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
                }
            }
        }
    }
}
