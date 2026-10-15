import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// The output's panel: a wavy level slider, the glyph as a mute button,
// and whichever device is being fed -- and under it, folded away until
// asked for, a mixer of the applications playing into it.
//
// The mixer is a row of faders after the Android volume panel's
// expanded form: a tall pill per application, filled from the bottom to
// its level, with the application's icon sitting in the fill's base.
// The fill never shrinks past the circle around the icon, so the icon
// is always the handle to grab, and the button that mutes. Inside the
// fill a lighter band follows what the stream is actually putting out,
// so the one that is making the noise can be told at a glance.
BlobPopup {
    id: root

    readonly property int panelWidth: 320

    // Remembered between openings: someone who reaches for the mixer
    // tends to want it every time.
    property bool mixerOpen: false

    readonly property bool mixerShown: open && mixerOpen

    readonly property int faderWidth: 52
    readonly property int faderHeight: 148
    readonly property int faderSpacing: Appearance.spacing.small

    // One application's fader.
    component Fader: Item {
        id: fader

        required property PwNode modelData
        required property int index

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
            running: root.mixerShown && !fader.risen
            interval: 40 + fader.index * 45
            onTriggered: fader.risen = true
        }

        Connections {
            target: root

            function onMixerShownChanged(): void {
                if (!root.mixerShown)
                    fader.risen = false;
            }
        }

        implicitWidth: root.faderWidth
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
            enabled: root.mixerShown && (fader.modelData.audio?.channels.length ?? 0) > 1
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
                Layout.preferredHeight: root.faderHeight

                radius: width / 2
                color: Appearance.palette.m3surfaceContainerHigh

                Rectangle {
                    id: fill

                    anchors.bottom: parent.bottom

                    width: parent.width
                    height: parent.width + track.span * fader.value * fader.rise

                    radius: parent.radius
                    color: fader.muted ? Appearance.palette.m3surfaceContainerHighest : Appearance.palette.m3primaryContainer

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
                        color: Appearance.palette.m3primary
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
                            color: fader.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onPrimaryContainer
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

                            color: Appearance.palette.m3error
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
                                color: Appearance.palette.m3onError
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
                    color: fill.height > track.height - Appearance.padding.small - 8 && !fader.muted ? Appearance.palette.m3onPrimaryContainer : Appearance.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                }

                // The state layer.
                Rectangle {
                    anchors.fill: parent

                    radius: parent.radius
                    color: Appearance.palette.m3onSurface
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
                color: fader.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
                elide: Text.ElideRight
            }
        }
    }

    // Held to one width open or shut: the panel follows its content's
    // height smoothly, but snaps to a new width.
    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: content.implicitHeight

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                // The glyph doubles as the mute button -- the same thing the
                // bar widget's middle click does.
                MaterialSymbol {
                    id: icon

                    Layout.alignment: Qt.AlignVCenter

                    icon: Audio.icon
                    size: Appearance.font.icon.large
                    color: Audio.muted ? Appearance.palette.m3error : Appearance.palette.m3primary
                    fill: Audio.muted ? 1 : 0

                    opacity: iconHover.hovered ? 1 : 0.85

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    HoverHandler {
                        id: iconHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Audio.toggleMute()
                    }
                }

                WavySlider {
                    id: slider

                    Layout.fillWidth: true

                    // Flat when there is nothing to hear, travelling when
                    // there is -- the same rule the media slider follows
                    // for paused and playing.
                    wavy: !Audio.muted && Audio.volume > 0
                    activeColor: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3primary

                    // Live rather than committed on release, as the media
                    // slider is: a volume you cannot hear until you let go
                    // is one you have to set twice.
                    onMoved: Audio.setVolume(value)

                    // Follows the sink only while the handle is not being
                    // dragged, so an external change -- a media key, another
                    // mixer -- moves it without fighting the pointer.
                    Binding on value {
                        when: !slider.pressed
                        value: Audio.volume
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 40

                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.volume * 100) + "%"
                    color: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true

                    animate: true
                    text: Audio.description || qsTr("No output")
                    color: Appearance.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                // Opens the mixer: a tonal chip carrying how many are
                // playing, so it is worth opening before it is opened.
                Rectangle {
                    id: chip

                    implicitWidth: chipRow.implicitWidth + Appearance.padding.medium * 2
                    implicitHeight: 32

                    radius: height / 2
                    color: root.mixerOpen ? Appearance.palette.m3secondaryContainer : Appearance.palette.m3surfaceContainerHigh

                    Behavior on color {
                        CAnim {}
                    }

                    HoverHandler {
                        id: chipHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.mixerOpen = !root.mixerOpen
                    }

                    Rectangle {
                        anchors.fill: parent

                        radius: parent.radius
                        color: Appearance.palette.m3onSurface
                        opacity: chipHover.hovered ? 0.08 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.extraSmall

                        readonly property color tint: root.mixerOpen ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onSurface

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter

                            icon: "tune"
                            size: Appearance.font.icon.small
                            color: chipRow.tint
                            fill: root.mixerOpen ? 1 : 0
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter

                            text: Audio.streams.length
                            color: chipRow.tint
                            font.weight: Font.Medium
                        }

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter

                            icon: "expand_more"
                            size: Appearance.font.icon.small
                            color: chipRow.tint
                            rotation: root.mixerOpen ? 180 : 0

                            Behavior on rotation {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }
                }
            }

            // The mixer. Laid out only while open: the panel follows the
            // content's height, so it grows down to take it in and draws
            // back up when it goes.
            Item {
                visible: root.mixerOpen

                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                implicitHeight: Audio.streams.length > 0 ? faders.contentHeight : empty.implicitHeight

                // Centred while they fit and scrolled sideways once they do
                // not, rather than squeezed.
                Flickable {
                    id: faders

                    anchors.fill: parent

                    visible: Audio.streams.length > 0

                    contentWidth: Math.max(width, row.implicitWidth)
                    contentHeight: row.implicitHeight
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: row.implicitWidth > width
                    clip: true

                    Row {
                        id: row

                        x: Math.max(0, (faders.width - implicitWidth) / 2)
                        spacing: root.faderSpacing

                        Repeater {
                            model: ScriptModel {
                                values: Audio.streams
                            }

                            Fader {}
                        }
                    }
                }

                ColumnLayout {
                    id: empty

                    anchors.centerIn: parent

                    visible: Audio.streams.length === 0
                    spacing: Appearance.spacing.extraSmall

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter

                        icon: "music_off"
                        size: Appearance.font.icon.large
                        color: Appearance.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Appearance.padding.small

                        text: qsTr("Nothing is playing")
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
