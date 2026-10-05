import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The media panel: art, track, a wavy progress slider and transport.
// With nothing playing it lists the players something could be started
// in.
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
                    color: Appearance.palette.m3surfaceContainerHighest
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

        // Nothing is: the players to start something in. A launched
        // player turns this into the view above as soon as it registers,
        // panel still open.
        ColumnLayout {
            id: idle

            visible: !Players.available
            spacing: Appearance.spacing.small

            Layout.preferredWidth: 300

            // The configured players that are actually installed.
            //
            // Reads Apps.all first so the binding depends on it, as the
            // dock's pinned row does: byId notifies nothing, and before
            // the entries are indexed every id resolves to null, which
            // would leave the list empty for good.
            readonly property var entries: {
                Apps.all;
                return Appearance.media.launchers.map(id => Apps.byId(id)).filter(e => e !== null);
            }

            // The one just tapped, until a player turns up or it is
            // given up on, so a slow start does not read as a click that
            // went nowhere.
            property string launching: ""

            Timer {
                id: launchGuard

                interval: 20000
                onTriggered: idle.launching = ""
            }

            Connections {
                target: Players

                function onAvailableChanged(): void {
                    idle.launching = "";
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Appearance.spacing.extraSmall
                spacing: Appearance.spacing.medium

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40

                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3surfaceContainerHighest

                    MaterialSymbol {
                        anchors.centerIn: parent

                        icon: "music_off"
                        size: Appearance.font.icon.normal
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: qsTr("Nothing playing")
                        font.pixelSize: Appearance.font.normal
                    }

                    StyledText {
                        visible: idle.entries.length > 0

                        text: qsTr("Start a player")
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }
            }

            Repeater {
                model: idle.entries

                Item {
                    id: player

                    required property DesktopEntry modelData

                    readonly property bool launching: idle.launching === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 48

                    HoverHandler {
                        id: playerHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            idle.launching = player.modelData.id;
                            launchGuard.restart();
                            Apps.launch(player.modelData);
                        }
                    }

                    // The M3 state layer.
                    Rectangle {
                        anchors.fill: parent

                        radius: Appearance.rounding.large
                        color: Appearance.palette.m3surfaceContainerHigh
                        opacity: playerHover.hovered || player.launching ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.padding.small
                        anchors.rightMargin: Appearance.padding.small
                        spacing: Appearance.spacing.medium

                        IconImage {
                            implicitSize: 32
                            source: Quickshell.iconPath(player.modelData.icon, "application-x-executable")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true

                                text: player.modelData.name
                                font.pixelSize: Appearance.font.normal
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true

                                visible: text.length > 0
                                text: player.modelData.genericName || player.modelData.comment || ""
                                color: Appearance.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        // An hourglass while the player starts, a play
                        // glyph on the row under the pointer otherwise.
                        MaterialSymbol {
                            opacity: playerHover.hovered || player.launching ? 1 : 0

                            icon: player.launching ? "hourglass_empty" : "play_arrow"
                            size: Appearance.font.icon.normal
                            color: Appearance.palette.m3primary
                            fill: 1

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
