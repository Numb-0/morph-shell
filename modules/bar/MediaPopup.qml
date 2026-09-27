import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The media panel: art, track, a wavy progress slider and transport.
// With nothing playing it offers the last track back, and the players
// it could be started in.
BlobPopup {
    id: root

    // The position is only polled while a panel shows it.
    onOpenChanged: Players.watchPosition(open)

    Component.onDestruction: if (open)
        Players.watchPosition(false)

    // A tap target around one transport glyph.
    component Button: Item {
        id: btn

        required property string icon

        signal activated

        implicitWidth: 40
        implicitHeight: 40

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

        MaterialSymbol {
            anchors.centerIn: parent

            icon: btn.icon
            size: Appearance.font.icon.normal

            // Solid, as the drawn icons were -- transport controls read
            // as buttons rather than as outlines.
            fill: 1
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        // A player is up: what it is playing and the controls for it.
        ColumnLayout {
            visible: Players.available
            spacing: Appearance.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64

                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3surface
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
                        color: Appearance.palette.m3onSurfaceVariant
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
                    color: Appearance.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Players.formatTime(Players.length)
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Appearance.spacing.large

                Button {
                    icon: "skip_previous"
                    visible: Players.canGoPrevious

                    onActivated: Players.active.previous()
                }

                Button {
                    icon: Players.playing ? "pause" : "play_arrow"
                    visible: Players.canTogglePlaying

                    onActivated: Players.active.togglePlaying()
                }

                Button {
                    icon: "skip_next"
                    visible: Players.canGoNext

                    onActivated: Players.active.next()
                }
            }
        }

        // Nothing is: the last track, to pick back up, and the players
        // to start something new in. A launched player turns this into
        // the view above as soon as it registers, panel still open.
        ColumnLayout {
            visible: !Players.available
            spacing: Appearance.spacing.medium

            Layout.preferredWidth: 300

            RowLayout {
                visible: Players.hasLast

                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64

                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3surface
                    clip: true

                    // Stands in for art the player never sent, or that
                    // has since gone -- browsers keep theirs in /tmp.
                    MaterialSymbol {
                        anchors.centerIn: parent

                        visible: lastArt.status !== Image.Ready

                        icon: "music_note"
                        size: Appearance.font.icon.large
                        color: Appearance.palette.m3onSurfaceVariant
                    }

                    Image {
                        id: lastArt

                        anchors.fill: parent

                        source: Players.last.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready

                        // Dimmed: a record of what played, not something
                        // playing now.
                        opacity: 0.6
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Appearance.spacing.extraSmall

                    StyledText {
                        text: qsTr("Last played")
                        color: Appearance.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true

                        text: Players.last.title
                        font.pixelSize: Appearance.font.normal
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true

                        text: [Players.last.artist, Players.last.identity].filter(t => t.length > 0).join(" \u00b7 ")
                        color: Appearance.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                // Starts the player again and plays once it is back. An
                // hourglass while that is under way, so a slow start does
                // not read as a click that went nowhere.
                Button {
                    icon: Players.resuming.length > 0 ? "hourglass_empty" : "play_arrow"

                    onActivated: Players.resume()
                }
            }

            StyledText {
                visible: !Players.hasLast

                text: qsTr("Nothing playing")
                font.pixelSize: Appearance.font.normal
                color: Appearance.palette.m3onSurfaceVariant
            }

            Flow {
                id: launchers

                // The configured players that are actually installed.
                readonly property var entries: Appearance.media.launchers.map(id => Apps.byId(id)).filter(e => e !== null)

                visible: entries.length > 0

                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: launchers.entries

                    Rectangle {
                        id: chip

                        required property DesktopEntry modelData

                        implicitWidth: chipRow.implicitWidth + Appearance.padding.medium * 2
                        implicitHeight: 36

                        radius: height / 2
                        color: Appearance.palette.m3surface
                        opacity: chipHover.hovered ? 1 : 0.85

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Apps.launch(chip.modelData)
                        }

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter

                                implicitSize: Appearance.font.icon.normal
                                source: Quickshell.iconPath(chip.modelData.icon, "application-x-executable")
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter

                                text: chip.modelData.name
                            }
                        }
                    }
                }
            }
        }
    }
}
