import QtQuick
import qs.components
import qs.config
import qs.services

// Bar widget: a recording under way, as a red dot breathing beside how
// long it has run. Pointing at it turns the dot into the stop square it
// would be on a recorder, and a click stops the recording.
//
// Not there at all while nothing is recording: it opens out of nothing
// beside the clock as a recording starts, and folds back as it stops.
Item {
    id: root

    readonly property bool hovered: hover.hovered

    readonly property real fullWidth: row.implicitWidth + Appearance.bar.itemPadding * 2

    implicitWidth: Recorder.recording ? fullWidth : 0
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

    visible: implicitWidth > 0
    clip: true

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Recorder.stop()
    }

    // Laid out from the left, so the row is uncovered from the clock's
    // side outward as the widget opens.
    Row {
        id: row

        x: Appearance.bar.itemPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: Appearance.spacing.small

        // The dot, or under the pointer the stop square: one shape whose
        // corners and size move between the two.
        Item {
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: Appearance.font.icon.normal
            implicitHeight: Appearance.font.icon.normal

            Rectangle {
                id: mark

                property real size: root.hovered ? parent.width * 0.62 : parent.width * 0.5

                anchors.centerIn: parent

                width: size
                height: size
                radius: root.hovered ? size * 0.22 : size / 2

                color: Appearance.palette.m3error

                Behavior on size {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on radius {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                // Breathes while recording, and holds still to be
                // clicked.
                SequentialAnimation on opacity {
                    running: Recorder.recording && !root.hovered
                    loops: Animation.Infinite

                    onRunningChanged: if (!running)
                        mark.opacity = 1

                    Anim {
                        to: 0.35
                        duration: 900
                        type: Anim.Standard
                    }
                    Anim {
                        to: 1
                        duration: 900
                        type: Anim.Standard
                    }
                }
            }

            // A ring that rolls out of the dot once a second, in step
            // with the timer.
            Rectangle {
                id: ripple

                anchors.centerIn: parent

                width: parent.width * 0.5
                height: width
                radius: width / 2

                color: "transparent"
                border.width: 1.5
                border.color: Appearance.palette.m3error

                opacity: 0
                visible: !root.hovered

                ParallelAnimation {
                    id: rippleAnim

                    Anim {
                        target: ripple
                        property: "scale"
                        from: 1
                        to: 2
                        duration: 800
                        type: Anim.Standard
                    }
                    Anim {
                        target: ripple
                        property: "opacity"
                        from: 0.8
                        to: 0
                        duration: 800
                        type: Anim.Standard
                    }
                }

                Connections {
                    target: Recorder

                    function onElapsedChanged(): void {
                        if (Recorder.recording)
                            rippleAnim.restart();
                    }
                }
            }
        }

        // Sound is being taken too.
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter

            visible: Recorder.audio
            icon: "volume_up"
            size: Appearance.font.icon.small
            color: Appearance.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            font.pixelSize: Appearance.font.normal

            text: {
                const s = Recorder.elapsed;
                const pad = n => String(n).padStart(2, "0");
                const time = `${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`;
                return s >= 3600 ? `${Math.floor(s / 3600)}:${time}` : time;
            }
        }
    }
}
