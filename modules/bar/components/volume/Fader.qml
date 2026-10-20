import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services.system

// One application's fader.
Item {
    id: fader

    required property PwNode modelData
    required property int index

    // Sizing and visibility come from the popup that lays the faders out.
    property bool mixerShown: false
    property real faderWidth: 0
    property real faderHeight: 0

    readonly property bool muted: modelData.audio?.muted ?? false
    readonly property real volume: modelData.audio?.volume ?? 0

    // Held while the pointer has it, so the stream catching up a
    // moment late does not tug the fill back under the finger.
    property real dragValue: -1
    readonly property real value: dragValue >= 0 ? dragValue : volume

    // Rises into place a beat after the one before it, so opening
    // the mixer reads as the faders standing up in turn rather than
    // appearing as a block.
    property bool risen: false
    property real rise: risen ? 1 : 0

    Behavior on rise {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Timer {
        running: fader.mixerShown && !fader.risen
        interval: 40 + fader.index * 45
        onTriggered: fader.risen = true
    }

    Connections {
        target: root

        function onMixerShownChanged(): void {
            if (!fader.mixerShown)
                fader.risen = false;
        }
    }

    implicitWidth: fader.faderWidth
    implicitHeight: column.implicitHeight

    opacity: rise
    transform: Translate {
        y: (1 - fader.rise) * 16
    }

    // Volume only stays current on a node something is tracking.
    PwObjectTracker {
        objects: [fader.modelData]
    }

    // Read only while the faders are on screen: each one is a capture
    // stream of its own in the graph. Not on a mono stream either:
    // the monitor captures in stereo whatever it is pointed at, and
    // against a mono node it logs a complaint every period and reads
    // nothing.
    PwNodePeakMonitor {
        id: peaks

        node: fader.modelData
        enabled: fader.mixerShown && (fader.modelData.audio?.channels.length ?? 0) > 1
    }

    // Shaped for the eye rather than the ear: a linear peak spends
    // most of its time near the bottom, which would leave the band
    // barely moving under anything but a full-scale signal.
    property real level: Math.sqrt(Math.max(0, Math.min(1, peaks.peak)))

    Behavior on level {
        Anim {
            type: Anim.FastEffects
        }
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.extraSmall

        Rectangle {
            id: track

            // The fill's span: from a circle around the icon at the
            // bottom to the track's full height.
            readonly property real span: height - width

            function valueAt(y: real): real {
                return Math.max(0, Math.min(1, 1 - (y - width / 2) / Math.max(1, span)));
            }

            Layout.fillWidth: true
            Layout.preferredHeight: fader.faderHeight

            radius: width / 2
            color: Colours.palette.m3surfaceContainerHigh

            Rectangle {
                id: fill

                anchors.bottom: parent.bottom

                width: parent.width
                height: parent.width + track.span * fader.value * fader.rise

                radius: parent.radius
                color: fader.muted ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3primaryContainer

                Behavior on color {
                    CAnim {}
                }

                // The live level, inside the fill and scaled to it,
                // so what you hear is never drawn above what you set.
                Rectangle {
                    anchors.bottom: parent.bottom

                    width: parent.width
                    height: parent.width + (parent.height - parent.width) * fader.level

                    radius: parent.radius
                    color: Colours.palette.m3primary
                    opacity: fader.muted ? 0 : 0.22 + fader.level * 0.2

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                // The handle: the application, in the fill's base.
                Item {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: parent.width
                    height: parent.width

                    readonly property string iconSource: Audio.streamIcon(fader.modelData)

                    Image {
                        id: appIcon

                        anchors.centerIn: parent

                        width: 26
                        height: 26
                        sourceSize.width: 52
                        sourceSize.height: 52

                        source: parent.iconSource
                        visible: status === Image.Ready
                        asynchronous: true

                        opacity: fader.muted ? 0.45 : 1

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent

                        visible: !appIcon.visible

                        icon: "graphic_eq"
                        color: fader.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onPrimaryContainer
                        fill: 1
                    }

                    // Muted, the icon wears the output's own mute
                    // glyph in its corner.
                    Rectangle {
                        x: parent.width / 2 + 3
                        y: parent.height / 2 + 1

                        width: 18
                        height: 18
                        radius: 9

                        color: Colours.palette.m3error
                        scale: fader.muted ? 1 : 0

                        Behavior on scale {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent

                            icon: "volume_off"
                            size: 12
                            color: Colours.palette.m3onError
                            fill: 1
                        }
                    }
                }
            }

            StyledText {
                anchors.top: parent.top
                anchors.topMargin: Appearance.padding.small
                anchors.horizontalCenter: parent.horizontalCenter

                text: Math.round(fader.value * 100)

                // Over the fill once it has climbed this far, under it
                // until then.
                color: fill.height > track.height - Appearance.padding.small - 8 && !fader.muted ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.weight: Font.Medium
            }

            // The state layer.
            Rectangle {
                anchors.fill: parent

                radius: parent.radius
                color: Colours.palette.m3onSurface
                opacity: area.pressed ? 0.1 : area.containsMouse ? 0.06 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            // Dragged anywhere, it sets the level; tapped, the icon
            // mutes and the rest of the track jumps there. A press on
            // the icon only becomes a drag once it has moved, so a
            // tap that wanders by a pixel still mutes.
            MouseArea {
                id: area

                property real pressY: 0
                property bool pressedIcon: false
                property bool dragging: false

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: mouse => {
                    pressY = mouse.y;
                    pressedIcon = mouse.y > height - width;
                    dragging = !pressedIcon;
                    if (dragging)
                        fader.dragValue = track.valueAt(mouse.y);
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;

                    if (!dragging && Math.abs(mouse.y - pressY) > 4)
                        dragging = true;

                    if (dragging) {
                        fader.dragValue = track.valueAt(mouse.y);
                        Audio.setStreamVolume(fader.modelData, fader.dragValue);
                    }
                }

                onReleased: mouse => {
                    if (dragging)
                        Audio.setStreamVolume(fader.modelData, track.valueAt(mouse.y));
                    else
                        Audio.toggleStreamMute(fader.modelData);

                    fader.dragValue = -1;
                    dragging = false;
                }

                onCanceled: {
                    fader.dragValue = -1;
                    dragging = false;
                }

                // As the bar widget scrolls the output.
                onWheel: wheel => Audio.setStreamVolume(fader.modelData, fader.volume + wheel.angleDelta.y / 120 * 0.05)
            }
        }

        StyledText {
            Layout.fillWidth: true

            text: Audio.streamName(fader.modelData)
            horizontalAlignment: Text.AlignHCenter
            color: fader.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
            elide: Text.ElideRight
        }
    }
}
