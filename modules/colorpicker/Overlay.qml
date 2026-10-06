pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Morph.Components
import qs.components
import qs.config

// One screen's share of the colour picker. The screen is frozen as it
// was on opening, and a lens beside the pointer magnifies the pixels
// under it, with the colour of the one in the middle written below. A
// click takes that colour.
//
// The frozen frame is copied once into a PixelSampler, at the capture's
// own size, so the colour read is the screen's pixel and not one the
// view blended from its neighbours at a fractional scale.
MouseArea {
    id: root

    required property ShellScreen screen

    signal picked(color color)
    signal cancelled

    // Where the pointer is. Starts off screen until the compositor says
    // otherwise, so a screen the pointer is not on shows no lens.
    property real pointerX: -1
    property real pointerY: -1
    readonly property bool pointerHere: pointerX >= 0 && pointerY >= 0 && pointerX < width && pointerY < height

    // The pixel under the pointer, in the capture's pixels.
    readonly property int pixelX: sampler.ready ? Math.floor(pointerX * sampler.size.width / width) : 0
    readonly property int pixelY: sampler.ready ? Math.floor(pointerY * sampler.size.height / height) : 0

    readonly property color current: sampler.ready && pointerHere ? sampler.colorAt(pixelX, pixelY) : "transparent"

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPositionChanged: event => {
        pointerX = event.x;
        pointerY = event.y;
    }

    onPressed: event => {
        if (event.button === Qt.RightButton) {
            cancelled();
            return;
        }
        pointerX = event.x;
        pointerY = event.y;
        if (sampler.ready && pointerHere)
            picked(current);
    }

    focus: true
    Keys.onEscapePressed: cancelled()

    PixelSampler {
        id: sampler
    }

    // Captured as the overlay opens, before it has drawn anything of its
    // own, so the frame is the screen as it was.
    ScreencopyView {
        id: frame

        anchors.fill: parent

        captureSource: root.screen
        live: false

        // Hidden until the sampler has it too, so the lens and the
        // frozen frame come up together.
        visible: sampler.ready

        // Asked for at the capture's size over the screen's scale: the
        // grab multiplies whatever it is given by that again.
        onHasContentChanged: {
            if (!hasContent)
                return;
            const native = sourceSize;
            const dpr = Screen.devicePixelRatio || 1;
            grabToImage(result => sampler.load(result, native), Qt.size(native.width / dpr, native.height / dpr));
        }
    }

    // The pointer's position before it has moved, so the lens is there
    // from the first frame rather than waiting on a wiggle.
    Process {
        running: true
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(text);
                    if (root.pointerX < 0) {
                        root.pointerX = pos.x - root.screen.x;
                        root.pointerY = pos.y - root.screen.y;
                    }
                } catch (e) {}
            }
        }
    }

    // The lens and its readout, down and to the right of the pointer, or
    // flipped to the other side where that would run off the screen.
    Column {
        id: loupe

        readonly property real gap: Appearance.spacing.large

        visible: sampler.ready && root.pointerHere
        spacing: Appearance.spacing.small

        x: root.pointerX + gap + width <= root.width ? root.pointerX + gap : root.pointerX - gap - width
        y: root.pointerY + gap + height <= root.height ? root.pointerY + gap : root.pointerY - gap - height

        Rectangle {
            readonly property int ring: 3

            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: 132 + ring * 2
            implicitHeight: implicitWidth
            radius: width / 2

            color: Appearance.palette.m3surfaceContainer
            border.width: ring
            border.color: Appearance.palette.m3primary

            PixelLens {
                anchors.fill: parent
                anchors.margins: parent.ring

                sampler: sampler
                centerX: root.pixelX
                centerY: root.pixelY
                cells: 11

                gridColor: {
                    const c = Appearance.palette.m3shadow;
                    return Qt.rgba(c.r, c.g, c.b, 0.18);
                }
                // Light or dark against the pixel it rings, so it shows
                // on any colour.
                markerColor: root.current.hslLightness > 0.5 ? "black" : "white"
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: readout.implicitWidth + Appearance.padding.medium * 2
            implicitHeight: readout.implicitHeight + Appearance.padding.extraSmall * 2
            radius: height / 2

            color: Appearance.palette.m3surfaceContainer

            Row {
                id: readout

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: hex.implicitHeight * 0.8
                    implicitHeight: implicitWidth
                    radius: width / 2

                    color: root.current
                    border.width: 1
                    border.color: Appearance.palette.m3outline
                }

                StyledText {
                    id: hex

                    text: root.current.toString().toUpperCase()
                    color: Appearance.palette.m3onSurface
                }
            }
        }
    }
}
