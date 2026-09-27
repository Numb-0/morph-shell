import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// A glance at the output level whenever it moves -- a media key, a
// scroll on the bar, another mixer -- floating up from the bottom of the
// screen and sinking away again once the level has been left alone.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        property bool shown: false

        // The sink comes up reading zero and jumps to its real level a
        // moment later, and switching outputs jumps it again. Neither is
        // anyone changing the volume, so changes are ignored until the
        // current sink has settled.
        property bool settled: false

        property real reveal: shown ? 1 : 0

        Behavior on reveal {
            Anim {
                type: Anim.Emphasized
            }
        }

        function poke(): void {
            if (!settled || !Audio.available)
                return;

            shown = true;
            hideTimer.restart();
        }

        Connections {
            target: Audio

            function onVolumeChanged(): void {
                win.poke();
            }

            function onMutedChanged(): void {
                win.poke();
            }

            function onSinkChanged(): void {
                win.settled = false;
                settleTimer.restart();
            }
        }

        Timer {
            id: settleTimer

            interval: 500
            running: true
            onTriggered: win.settled = true
        }

        Timer {
            id: hideTimer

            interval: Appearance.osd.timeout
            onTriggered: win.shown = false
        }

        screen: modelData
        color: "transparent"
        visible: reveal > 0

        // Above everything, reserving nothing and taking no input: it is
        // there to be read, never to be in the way of a click.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "morph-shell-osd"
        exclusiveZone: 0
        mask: Region {}

        anchors.bottom: true

        implicitWidth: pill.implicitWidth
        implicitHeight: pill.implicitHeight + Appearance.osd.margin + Appearance.spacing.large * 2

        Rectangle {
            id: pill

            anchors.horizontalCenter: parent.horizontalCenter

            // Rises from below its resting place as it fades in, the way
            // the dock slides up, and sinks back as it goes.
            y: parent.height - Appearance.osd.margin - height + Appearance.spacing.large * 2 * (1 - win.reveal)
            opacity: win.reveal

            implicitWidth: row.implicitWidth + Appearance.padding.large * 2
            implicitHeight: row.implicitHeight + Appearance.padding.medium * 2

            radius: height / 2
            color: Appearance.palette.m3surfaceContainer

            RowLayout {
                id: row

                anchors.centerIn: parent
                spacing: Appearance.spacing.medium

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter

                    icon: Audio.icon
                    size: Appearance.font.icon.large
                    color: Audio.muted ? Appearance.palette.m3error : Appearance.palette.m3primary
                    fill: Audio.muted ? 1 : 0
                }

                // The same slider as the bar's volume panel, read-only
                // here -- the window takes no input.
                WavySlider {
                    Layout.preferredWidth: 220
                    Layout.alignment: Qt.AlignVCenter

                    value: Audio.volume
                    wavy: !Audio.muted && Audio.volume > 0

                    // The window unmapping does not hide its items, so
                    // the wave is stopped by hand while the OSD is down.
                    animateWave: wavy && win.visible
                    activeColor: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3primary
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 40

                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.volume * 100) + "%"
                    font.pixelSize: Appearance.font.normal
                    color: Audio.muted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3onSurface
                }
            }
        }
    }
}
