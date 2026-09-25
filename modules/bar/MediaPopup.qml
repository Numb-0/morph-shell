import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The media panel: art, track, a wavy progress slider and transport.
BlobPopup {
    id: root

    // A tap target around one of the shape-drawn transport icons.
    component Button: Item {
        id: btn

        required property string kind

        signal activated

        implicitWidth: 34
        implicitHeight: 34

        opacity: hover.hovered ? 1 : 0.85

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: btn.activated()
        }

        PlayerIcon {
            anchors.centerIn: parent

            kind: btn.kind
            color: Appearance.palette.text
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.medium

            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64

                radius: Appearance.rounding.medium
                color: Appearance.palette.background
                clip: true

                Image {
                    anchors.fill: parent

                    source: Players.active?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Appearance.spacing.extraSmall

                StyledText {
                    Layout.maximumWidth: 220

                    animate: true
                    text: Players.active?.trackTitle ?? qsTr("Nothing playing")
                    font.pixelSize: Appearance.font.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.maximumWidth: 220

                    animate: true
                    text: Players.active?.trackArtist ?? ""
                    color: Appearance.palette.subtext
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        WavySlider {
            id: slider

            // Nothing to scrub without a duration, so it goes away
            // rather than sitting there inert.
            visible: Players.lengthKnown

            Layout.fillWidth: true
            Layout.preferredWidth: 300

            enabled: Players.seekable

            // Flat while paused, travelling while playing.
            wavy: Players.playing

            // Committed on release rather than on every move, so dragging
            // does not spam the player with seeks.
            onPressedChanged: if (!pressed)
                Players.seek(value)

            // Follows the player only while the handle is not being
            // dragged; Players holds the dropped position until the
            // player reports it back.
            Binding on value {
                when: !slider.pressed
                value: Players.progress
            }
        }

        RowLayout {
            visible: Players.lengthKnown

            Layout.fillWidth: true

            StyledText {
                text: Players.formatTime(Players.position)
                color: Appearance.palette.subtext
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: Players.formatTime(Players.length)
                color: Appearance.palette.subtext
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.large

            Button {
                kind: "previous"
                visible: Players.canGoPrevious

                onActivated: Players.active.previous()
            }

            Button {
                kind: Players.playing ? "pause" : "play"
                visible: Players.canTogglePlaying

                onActivated: Players.active.togglePlaying()
            }

            Button {
                kind: "next"
                visible: Players.canGoNext

                onActivated: Players.active.next()
            }
        }
    }
}
