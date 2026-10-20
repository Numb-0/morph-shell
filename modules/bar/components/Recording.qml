import QtQuick
import qs.components
import qs.config
import qs.services.launcher
import qs.services.session

// Bar widget: the screen recorder's button. Idle it is a ring, as on a
// recorder, that fills red under the pointer: a click picks a region to
// record, a right click one to record with sound.
//
// Recording, the ring closes into a red dot breathing beside how long it
// has run, the widget opening out to the time. Pointing at it turns the
// dot into the stop square, and a click stops the recording.
Item {
    id: root

    readonly property bool hovered: hover.hovered
    readonly property bool recording: Recorder.recording

    readonly property real idleWidth: markBox.implicitWidth + Appearance.bar.itemPadding * 2
    readonly property real fullWidth: row.implicitWidth + Appearance.bar.itemPadding * 2

    implicitWidth: recording ? fullWidth : idleWidth
    implicitHeight: row.implicitHeight + Appearance.padding.small * 2

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
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onTapped: (point, button) => {
            if (root.recording)
                Recorder.stop();
            else
                Commands.recordRequested(button === Qt.RightButton);
        }
    }

    // Laid out from the left, so the time is uncovered from the button's
    // side outward as the widget opens. Always laid out in full: the
    // widget's own width is what hides the time while idle, so it slides
    // away under the clip rather than vanishing first.
    Row {
        id: row

        x: Appearance.bar.itemPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: Appearance.spacing.small

        // The ring, the dot, or under the pointer the stop square: one
        // shape whose fill, corners and size move between the three.
        Item {
            id: markBox

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: Appearance.font.icon.normal
            implicitHeight: Appearance.font.icon.normal

            Rectangle {
                id: mark

                // Idle the ring takes the glyph's whole box, filling in
                // under the pointer; recording it closes into the dot, and
                // under the pointer squares off into stop.
                property real size: !root.recording ? parent.width * 0.7 : root.hovered ? parent.width * 0.62 : parent.width * 0.5

                anchors.centerIn: parent

                width: size
                height: size
                radius: root.recording && root.hovered ? size * 0.22 : size / 2

                color: root.recording || root.hovered ? Appearance.palette.m3error : "transparent"
                border.width: root.recording ? 0 : 2
                border.color: root.hovered ? Appearance.palette.m3error : Appearance.palette.m3primary

                Behavior on color {
                    CAnim {}
                }

                Behavior on border.color {
                    CAnim {}
                }

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
