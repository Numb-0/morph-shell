import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// The desktop wallpaper, drawn by the shell so a theme switch can fade
// from one image to the next instead of cutting. The image comes from
// Appearance.wallpaper; with none, the screen is plain surface.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        color: Appearance.palette.m3surface

        // Under every window, over the whole screen, reserving nothing
        // and taking no input.
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "morph-shell-background"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Two layers take turns. A new image loads into the hidden one
        // and fades in over the one showing once it is decoded, so the
        // old image stays up while the new one loads.
        property Image front: null
        property Image incoming: null

        readonly property string path: Appearance.wallpaper

        onPathChanged: change()
        Component.onCompleted: change()

        function change(): void {
            // A change landing mid-fade finishes that fade on the spot
            // rather than starting from a blend of two images.
            if (fade.running) {
                fade.stop();
                fade.target.opacity = fade.to;
                done();
            } else if (incoming) {
                incoming.source = "";
                incoming = null;
            }

            if (!path) {
                if (front) {
                    fade.target = front;
                    fade.from = front.opacity;
                    fade.to = 0;
                    fade.start();
                }
                return;
            }

            const next = front === first ? second : first;
            const other = next === first ? second : first;
            next.z = 1;
            other.z = 0;
            next.opacity = 0;
            // Marked before the source is set: a file that is missing
            // fails on the spot, before the assignment returns.
            incoming = next;
            next.source = `file://${path}`;
        }

        function fadeIn(layer: Image): void {
            fade.target = layer;
            fade.from = 0;
            fade.to = 1;
            fade.start();
        }

        function done(): void {
            if (incoming) {
                const old = front;
                front = incoming;
                incoming = null;
                if (old) {
                    old.opacity = 0;
                    old.source = "";
                }
            } else if (front && front.opacity === 0) {
                front.source = "";
                front = null;
            }
        }

        component Layer: Image {
            anchors.fill: parent

            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0

            // Decoded at the screen's size rather than the file's, which
            // for a large wallpaper is most of the memory it would take.
            sourceSize.width: win.width * win.modelData.devicePixelRatio
            sourceSize.height: win.height * win.modelData.devicePixelRatio

            onStatusChanged: {
                if (this !== win.incoming)
                    return;
                if (status === Image.Ready) {
                    win.fadeIn(this);
                } else if (status === Image.Error) {
                    console.warn(`background: could not load ${win.path}`);
                    source = "";
                    win.incoming = null;
                }
            }
        }

        Layer {
            id: first
        }

        Layer {
            id: second
        }

        // Longer than the palette's fade: a whole screen changing reads
        // better unhurried.
        NumberAnimation {
            id: fade

            property: "opacity"
            duration: 900
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.standard

            onFinished: win.done()
        }
    }
}
