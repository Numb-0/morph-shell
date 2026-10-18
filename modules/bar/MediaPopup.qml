import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services

// The media panel: art, track, a wavy progress slider and transport.
// With nothing playing it keeps the same shape, the placeholder art at
// rest beside a line saying so.
BlobPopup {
    id: root

    // The position is only polled while a panel shows it.
    onOpenChanged: Players.watchPosition(open)

    Component.onDestruction: if (open)
        Players.watchPosition(false)

    // One transport control: a pill stretched across its share of the
    // row. The primary one is filled and takes a wider share, as the
    // action the panel is mostly opened for; the others are tonal. A
    // toggle is narrower and takes no share at all: bare while off,
    // filled with the secondary container while on.
    component Button: Item {
        id: btn

        required property string icon
        property bool primary: false
        property bool toggle: false
        property bool checked: false

        signal activated

        implicitWidth: toggle ? 36 : 48
        implicitHeight: 48

        Layout.fillWidth: !toggle
        Layout.horizontalStretchFactor: primary ? 2 : 1

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                glyph.press();
                btn.activated();
            }
        }

        // A toggle's is a circle in the middle of the row's height.
        Rectangle {
            anchors.centerIn: parent

            width: parent.width
            height: btn.toggle ? width : parent.height
            radius: height / 2
            color: btn.primary ? Appearance.palette.m3primary : btn.toggle ? Qt.alpha(Appearance.palette.m3secondaryContainer, btn.checked ? 1 : 0) : Appearance.palette.m3surfaceContainerHigh

            Behavior on color {
                CAnim {}
            }

            // The M3 state layer.
            Rectangle {
                anchors.fill: parent

                radius: parent.radius
                color: btn.primary ? Appearance.palette.m3onPrimary : btn.checked ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface
                opacity: hover.hovered ? 0.08 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }
        }

        MaterialSymbol {
            id: glyph

            anchors.centerIn: parent

            icon: btn.icon
            size: btn.primary ? Appearance.font.icon.large : Appearance.font.icon.normal
            color: btn.primary ? Appearance.palette.m3onPrimary : btn.toggle ? (btn.checked ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurfaceVariant) : Appearance.palette.m3onSurface

            // Solid, as the drawn icons were -- transport controls read
            // as buttons rather than as outlines.
            fill: 1
        }
    }

    // One bar of the placeholder's equaliser. It bobs on its own period,
    // so a few side by side never move in step, and only as far as
    // energy lets it: at rest it is a short pill.
    component EqBar: Rectangle {
        id: bar

        required property int period
        property real energy: 0
        property real level: 0.5

        anchors.bottom: parent?.bottom

        width: 8
        height: 10 + level * energy * 36
        radius: width / 2
        color: Appearance.palette.m3onPrimaryContainer

        // Only while it is seen and has somewhere to go; hidden or
        // paused, nothing should keep the animation driver ticking.
        SequentialAnimation on level {
            running: bar.visible && bar.energy > 0
            loops: Animation.Infinite

            NumberAnimation {
                to: 1
                duration: bar.period
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 0.15
                duration: bar.period
                easing.type: Easing.InOutSine
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        // What is playing and the controls for it. With no player the
        // controls and slider hide themselves, as they do for a player
        // that offers none of them.
        ColumnLayout {
            spacing: Appearance.spacing.medium

            Layout.preferredWidth: 360

            // The art, and beside it the track over the transport, so
            // the controls take no row of their own.
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                Rectangle {
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 104
                    Layout.alignment: Qt.AlignTop

                    radius: Appearance.rounding.large
                    color: Appearance.palette.m3surfaceContainerHighest
                    clip: true

                    // Under the art, for players that publish none: a
                    // wash of the scheme's containers with an equaliser
                    // that dances while the music plays and lies down
                    // when it stops.
                    Rectangle {
                        id: placeholder

                        anchors.fill: parent

                        visible: !art.visible
                        radius: parent.radius

                        // Eased rather than switched, so pausing lets the
                        // bars settle instead of dropping.
                        property real energy: Players.playing ? 1 : 0

                        Behavior on energy {
                            Anim {
                                type: Anim.SlowEffects
                            }
                        }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Appearance.palette.m3primaryContainer
                            }

                            GradientStop {
                                position: 1
                                color: Appearance.palette.m3tertiaryContainer
                            }
                        }

                        Row {
                            anchors.centerIn: parent

                            // Held at the tallest a bar gets, so the row
                            // does not recentre as they grow and shrink.
                            height: 46
                            spacing: 6

                            EqBar {
                                period: 620
                                energy: placeholder.energy
                            }

                            EqBar {
                                period: 470
                                energy: placeholder.energy
                            }

                            EqBar {
                                period: 760
                                energy: placeholder.energy
                            }

                            EqBar {
                                period: 540
                                energy: placeholder.energy
                            }
                        }
                    }

                    Image {
                        id: art

                        anchors.fill: parent

                        source: Players.active?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Appearance.spacing.extraSmall

                    // Up to two lines: titles run long, and the width
                    // beside the art is there to hold them.
                    StyledText {
                        Layout.fillWidth: true

                        animate: true
                        text: Players.available ? (Players.active.trackTitle || qsTr("Unknown title")) : qsTr("Nothing playing")
                        font.pixelSize: Appearance.font.normal
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true

                        animate: true
                        text: [Players.active?.trackArtist, Players.active?.trackAlbum].filter(s => s).join(" · ")
                        color: Appearance.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }

                    // Pushes the transport down to the art's bottom edge.
                    Item {
                        Layout.fillHeight: true
                    }

                    // Across the whole width beside the art.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Button {
                            icon: "shuffle"
                            toggle: true
                            checked: Players.shuffle
                            visible: Players.canShuffle

                            onActivated: Players.toggleShuffle()
                        }

                        Button {
                            icon: "skip_previous"
                            visible: Players.canGoPrevious

                            onActivated: Players.active.previous()
                        }

                        Button {
                            icon: Players.playing ? "pause" : "play_arrow"
                            primary: true
                            visible: Players.canTogglePlaying

                            onActivated: Players.active.togglePlaying()
                        }

                        Button {
                            icon: "skip_next"
                            visible: Players.canGoNext

                            onActivated: Players.active.next()
                        }

                        Button {
                            icon: Players.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                            toggle: true
                            checked: Players.loopState !== MprisLoopState.None
                            visible: Players.canLoop

                            onActivated: Players.cycleLoop()
                        }
                    }
                }
            }

            // The times either side of the slider rather than on a row
            // under it. Both are held to the width of the longer one, so
            // the slider does not change length as the position ticks.
            RowLayout {
                // Nothing to scrub without a duration, so it goes away
                // rather than sitting there inert.
                visible: Players.lengthKnown

                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                TextMetrics {
                    id: timeMetrics

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.small
                    text: Players.formatTime(Players.length)
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.advanceWidth

                    text: Players.formatTime(Players.position)
                    color: Appearance.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }

                WavySlider {
                    id: slider

                    Layout.fillWidth: true

                    enabled: Players.seekable

                    // Flat while paused, travelling while playing.
                    wavy: Players.playing

                    // Committed on release rather than on every move, so
                    // dragging does not spam the player with seeks.
                    onPressedChanged: if (!pressed)
                        Players.seek(value)

                    // Follows the player only while the handle is not
                    // being dragged; Players holds the dropped position
                    // until the player reports it back.
                    Binding on value {
                        when: !slider.pressed
                        value: Players.progress
                    }
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.advanceWidth

                    text: Players.formatTime(Players.length)
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
