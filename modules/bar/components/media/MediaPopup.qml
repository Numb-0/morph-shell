import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services.session

// The media panel: art, track, a wavy progress slider and transport.
// With nothing playing it keeps the same shape, the placeholder art at
// rest beside a line saying so.
BlobPopup {
    id: root

    // The position is only polled while a panel shows it.
    onOpenChanged: Players.watchPosition(open)

    Component.onDestruction: if (open)
        Players.watchPosition(false)

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

                            visible: opacity > 0
                            opacity: Players.available ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }

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

                    // With no player at all, an expressive shape in
                    // place of the equaliser, turning slowly behind a
                    // note. Every few seconds it sheds its lobes down to
                    // a circle and springs back out as the next shape,
                    // as the active workspace does on a switch.
                    Item {
                        id: idle

                        anchors.fill: parent

                        visible: opacity > 0
                        opacity: Players.available ? 0 : 1

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        // Only while it can be seen.
                        readonly property bool running: visible && root.open

                        readonly property var shapes: [
                            { lobes: 9, depth: 0.09 }, // cookie
                            { lobes: 4, depth: 0.2 }, // clover
                            { lobes: 8, depth: 0.1 }, // sunny
                            { lobes: 6, depth: 0.13 }, // flower
                            { lobes: 5, depth: 0.16 } // puffy
                        ]

                        property int shapeIndex: 0

                        // 0 is a plain circle, 1 the shape in full.
                        property real bloom: 1

                        // Quarter turns taken on each morph, over the
                        // idle spin.
                        property real turn: 0
                        property real spin: 0

                        Behavior on turn {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }

                        NumberAnimation on spin {
                            running: idle.running
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 12000
                        }

                        Timer {
                            running: idle.running
                            interval: 3200
                            repeat: true

                            onTriggered: {
                                idle.turn += 1;
                                morph.restart();
                            }
                        }

                        SequentialAnimation {
                            id: morph

                            Anim {
                                target: idle
                                property: "bloom"
                                to: 0
                                type: Anim.FastEffects
                            }
                            ScriptAction {
                                script: idle.shapeIndex = (idle.shapeIndex + 1) % idle.shapes.length
                            }
                            Anim {
                                target: idle
                                property: "bloom"
                                to: 1
                                type: Anim.FastSpatial
                            }
                        }

                        // The outline is rebuilt only while it morphs;
                        // the turning is a transform on the finished path.
                        Shape {
                            id: idleShape

                            readonly property real radius: 30
                            readonly property real c: width / 2

                            readonly property var outline: {
                                const s = idle.shapes[idle.shapeIndex];
                                const a = s.depth * idle.bloom;
                                const out = [];
                                for (let i = 0; i <= 120; i++) {
                                    const th = i / 120 * Math.PI * 2;
                                    const d = radius * (1 - a * 0.35 + a * Math.cos(s.lobes * th));
                                    out.push(Qt.point(c + Math.cos(th) * d, c + Math.sin(th) * d));
                                }
                                return out;
                            }

                            anchors.centerIn: parent

                            // Room for the lobes, which reach past the
                            // radius at full bloom.
                            width: radius * 2.4
                            height: width

                            preferredRendererType: Shape.CurveRenderer

                            transform: Rotation {
                                origin.x: idleShape.c
                                origin.y: idleShape.c
                                angle: idle.spin + idle.turn * 90
                            }

                            ShapePath {
                                fillColor: Appearance.palette.m3primary
                                strokeWidth: -1

                                PathPolyline {
                                    path: idleShape.outline
                                }
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent

                            icon: "music_note"
                            size: Appearance.font.icon.large
                            color: Appearance.palette.m3onPrimary
                            fill: 1
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

                    // With nothing playing there is no transport to sit
                    // over, so the text centres on the art instead of
                    // hanging from its top edge.
                    Item {
                        Layout.fillHeight: true
                        visible: !Players.available
                    }

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

                        MediaButton {
                            icon: "shuffle"
                            toggle: true
                            checked: Players.shuffle
                            visible: Players.canShuffle

                            onActivated: Players.toggleShuffle()
                        }

                        MediaButton {
                            icon: "skip_previous"
                            visible: Players.canGoPrevious

                            onActivated: Players.active.previous()
                        }

                        MediaButton {
                            icon: Players.playing ? "pause" : "play_arrow"
                            primary: true
                            visible: Players.canTogglePlaying

                            onActivated: Players.active.togglePlaying()
                        }

                        MediaButton {
                            icon: "skip_next"
                            visible: Players.canGoNext

                            onActivated: Players.active.next()
                        }

                        MediaButton {
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
