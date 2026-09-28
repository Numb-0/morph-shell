pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Morph.Blobs
import Morph.Components
import qs.components
import qs.config
import qs.services

// Notifications as they arrive, told as liquid.
//
// Every popup is a blob in one group, so they behave as drops of the same
// stuff. A new one wells up out of a spout at the top edge of the screen,
// stretches a neck as it falls, pinches off, and lands in the stack --
// then swells from a droplet into a card, pushing the others down as it
// grows. Running out, a card shrinks back into a droplet, and the ones
// below flow up through it and swallow it. Flicked towards the edge it
// wobbles off the screen under its own momentum.
//
// None of that is drawn by hand: it is the blob group's smoothing doing
// what it already does for the bar's panels, with each popup given a
// shape to animate between.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property int cardWidth: Appearance.notifs.width
        readonly property int drop: Appearance.notifs.drop

        // Where the stack's column sits, and so the spout above it.
        readonly property real columnX: width - Appearance.notifs.margin - cardWidth
        readonly property real columnCentre: columnX + cardWidth / 2

        screen: modelData
        color: "transparent"

        // Above everything and reserving nothing, as the OSD is. Only the
        // cards themselves take the pointer.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "morph-shell-notifications"
        exclusiveZone: 0

        mask: Region {
            item: hitArea
        }

        anchors {
            top: true
            right: true
            bottom: true
        }

        // Room either side of the column for a card overshooting as it
        // swells, and for one wobbling as it is dragged back.
        implicitWidth: cardWidth + Appearance.notifs.margin * 2 + 32

        Item {
            id: hitArea

            x: stack.x
            y: stack.y
            width: stack.width
            height: stack.height
        }

        // What should be up: newest first, and past the cap the oldest
        // wait in the centre instead of running down the screen.
        readonly property var wanted: Notifs.popups.slice(0, Appearance.notifs.maxPopups)

        // What is drawn: everything wanted, plus whatever is still on its
        // way out. A toast leaves this only once its own exit has played
        // through, so a burst of arrivals and departures never cuts one
        // off halfway -- which a view's transitions would.
        property var shown: []

        onWantedChanged: sync()
        Component.onCompleted: sync()

        function sync(): void {
            const fresh = wanted.filter(n => !shown.includes(n));
            if (fresh.length > 0)
                shown = [...fresh, ...shown];
        }

        function release(notif: var): void {
            shown = shown.filter(n => n !== notif);
            sync();
        }

        BlobGroup {
            id: group

            color: Appearance.palette.m3surfaceContainer
            smoothing: Appearance.notifs.smoothing
        }

        // The spout. Pokes a little way out of the top edge while a drop
        // is being born and draws back in after, so the new one has
        // something to be pulled out of.
        BlobRect {
            id: spout

            property real out: dripping.running ? 1 : 0

            Behavior on out {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            x: win.columnCentre - width / 2
            y: -height + 12 * out
            width: win.drop + 14
            height: 32

            group: group
            radius: height / 2
            deformScale: 0
        }

        // Held for as long as the spout should stay out: restarted by each
        // birth, so a burst of arrivals keeps it open between them.
        Timer {
            id: dripping

            interval: 700
        }

        // Laid out as a plain column. Every toast's height -- gap
        // included -- grows in as it is born and drains away as it
        // leaves, so the stack never jumps: it pushes and closes up with
        // them.
        Column {
            id: stack

            x: win.columnX
            y: Appearance.notifs.top
            width: win.cardWidth

            Repeater {
                model: ScriptModel {
                    values: win.shown
                }

                delegate: Item {
                    id: toast

                    required property var modelData
                    required property int index

                    readonly property var notif: modelData

                    // Born empty-handed and brought in by its own
                    // animation, below, rather than by the view's.
                    //
                    // 0 while still a droplet above the screen, 1 once it
                    // has landed.
                    property real fall: 0

                    // 0 as a droplet, 1 as a card.
                    property real morph: 0

                    // How much room it takes in the column, gap included:
                    // grows in as it arrives, drains away as it goes.
                    property real presence: 0

                    // The droplet itself shrinking to nothing at the end.
                    property real vanish: 1

                    property real dragX: 0

                    // Grows a touch under the pointer, as though it were
                    // leaning in.
                    property real lean: hover.hovered && !leaving ? 1 : 0

                    // A critical one breathes while it waits to be read.
                    property real pulse: 0

                    property bool leaving: false

                    // The time left, sampled from the service's clock each
                    // frame the toast is drawn.
                    property real remaining: notif.fraction()

                    FrameAnimation {
                        running: !toast.leaving && toast.notif.popup
                        onTriggered: toast.remaining = toast.notif.fraction()
                    }

                    // Taken down from elsewhere -- dismissed in the centre,
                    // cleared, pushed past the cap -- rather than by
                    // anything on the toast itself.
                    readonly property bool wanted: win.wanted.includes(notif)

                    onWantedChanged: if (!wanted)
                        leave("drop", null)

                    readonly property int padding: Appearance.padding.large
                    readonly property int waveRoom: 10
                    readonly property real cardHeight: content.implicitHeight + padding * 2 + waveRoom

                    // The card's height as laid out, before any lean or
                    // pulse, which spill over rather than shove.
                    readonly property real bodyHeight: win.drop + (cardHeight - win.drop) * Math.max(0, morph)

                    readonly property real shapeWidth: (win.drop + (width - win.drop) * morph + 10 * lean + 8 * pulse) * vanish
                    readonly property real shapeHeight: (win.drop + (cardHeight - win.drop) * morph + 6 * lean + 4 * pulse) * vanish

                    Behavior on lean {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    width: win.cardWidth
                    height: (bodyHeight + Appearance.notifs.gap) * presence

                    // Over its neighbours while falling past them or being
                    // dragged across them.
                    z: drag.active || fall < 1 ? 1 : 0

                    SequentialAnimation on pulse {
                        running: toast.notif.critical && !toast.leaving && win.visible
                        loops: Animation.Infinite

                        Anim {
                            to: 1
                            type: Anim.SlowEffects
                            duration: 900
                        }

                        Anim {
                            to: 0
                            type: Anim.SlowEffects
                            duration: 900
                        }
                    }

                    Component.onCompleted: birth.start()

                    // The spout opens, the drop falls out of it and lands
                    // -- making room as it comes -- then swells into the
                    // card.
                    SequentialAnimation {
                        id: birth

                        ScriptAction {
                            script: dripping.restart()
                        }

                        PauseAnimation {
                            duration: 110
                        }

                        ParallelAnimation {
                            Anim {
                                target: toast
                                property: "fall"
                                to: 1
                                type: Anim.FastSpatial
                            }

                            Anim {
                                target: toast
                                property: "presence"
                                to: 1
                                type: Anim.DefaultSpatial
                            }
                        }

                        Anim {
                            target: toast
                            property: "morph"
                            to: 1
                            type: Anim.DefaultSpatial
                        }
                    }

                    // Every way out ends the same: whatever is left
                    // shrinks to nothing while the ones below flow up
                    // over it and swallow it.
                    // How it goes: "absorb" when it ran out, slowly deflating;
                    // "pop" when closed or clicked, the same but quick;
                    // "fling" when flicked off the edge; "drop" when taken
                    // down elsewhere.
                    function leave(how: string, then: var): void {
                        if (leaving)
                            return;
                        leaving = true;
                        birth.stop();
                        exit.how = how;
                        exit.then = then;
                        exit.start();
                    }

                    SequentialAnimation {
                        id: exit

                        property string how
                        property var then: null

                        ParallelAnimation {
                            Anim {
                                target: toast
                                property: "morph"
                                to: exit.how === "fling" ? 0.4 : 0
                                type: exit.how === "absorb" ? Anim.Emphasized : exit.how === "fling" ? Anim.Standard : Anim.FastSpatial
                            }

                            Anim {
                                target: toast
                                property: "dragX"
                                to: exit.how === "fling" ? win.width - win.columnX + 40 : toast.dragX
                                type: Anim.Standard
                            }

                            Anim {
                                target: toast
                                property: "fall"
                                to: 1
                                type: Anim.FastEffects
                            }
                        }

                        ScriptAction {
                            script: exit.then?.()
                        }

                        ParallelAnimation {
                            Anim {
                                target: toast
                                property: "vanish"
                                to: 0
                                type: Anim.SlowEffects
                            }

                            Anim {
                                target: toast
                                property: "presence"
                                to: 0
                                type: Anim.Emphasized
                            }
                        }

                        ScriptAction {
                            script: win.release(toast.notif)
                        }
                    }

                    Connections {
                        target: toast.notif

                        function onTimedOut(): void {
                            toast.leave("absorb", () => toast.notif.hidePopup());
                        }
                    }

                    HoverHandler {
                        id: hover

                        onHoveredChanged: toast.notif.hold(hovered)
                    }

                    Component.onDestruction: if (hover.hovered)
                        toast.notif?.hold(false)

                    // Right is towards the edge, and the way out. Pulled the other way
                    // it gives only grudgingly and springs back.
                    DragHandler {
                        id: drag

                        target: null
                        enabled: !toast.leaving
                        yAxis.enabled: false

                        onActiveTranslationChanged: if (active) {
                            const t = activeTranslation.x;
                            toast.dragX = t > 0 ? t : t * 0.25;
                        }

                        onActiveChanged: if (!active) {
                            if (toast.dragX > 110 || centroid.velocity.x > 900)
                                toast.leave("fling", () => toast.notif.dismiss());
                            else
                                toast.dragX = 0;
                        }
                    }

                    // The body is the default action when there is one, and otherwise
                    // just puts the popup away.
                    TapHandler {
                        enabled: !toast.leaving

                        onTapped: {
                            if (toast.notif.hasDefault)
                                toast.notif.invoke("default");
                            else
                                toast.leave("pop", () => toast.notif.dismiss());
                        }
                    }

                    Behavior on dragX {
                        enabled: !drag.active && !toast.leaving

                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    BlobRect {
                        id: shape

                        // Falls from just above the screen, out of the
                        // spout, to its place in the stack.
                        readonly property real fallFrom: -(stack.y + toast.y + win.drop)

                        x: (toast.width - width) / 2 + toast.dragX
                        y: fallFrom * (1 - toast.fall) + (toast.bodyHeight * toast.presence - height) / 2
                        width: toast.shapeWidth
                        height: toast.shapeHeight

                        group: group
                        radius: Math.min(height / 2, win.drop / 2 + (Appearance.rounding.extraLarge - win.drop / 2) * toast.morph)

                        // Squash and stretch: the drop lengthens as it falls and the
                        // card wobbles as it is dragged and let go.
                        deformScale: 0.00006
                    }

                    // Clipped to the shape so nothing shows outside it while it grows
                    // or deflates. The text keeps the card's width throughout rather
                    // than reflowing with it.
                    Item {
                        x: shape.x
                        y: shape.y
                        width: shape.width
                        height: shape.height

                        clip: true
                        opacity: Math.max(0, Math.min(1, (toast.morph - 0.65) / 0.35)) * toast.vanish
                        visible: opacity > 0

                        NotificationContent {
                            id: content

                            x: toast.padding - (toast.width - shape.width) / 2
                            y: toast.padding
                            width: toast.width - toast.padding * 2

                            notif: toast.notif
                            showClose: hover.hovered

                            onCloseRequested: toast.leave("pop", () => toast.notif.dismiss())
                        }

                        // The time left, as a wave that drains back towards the start.
                        // It goes still while the pointer holds the popup.
                        WavyLine {
                            id: wave

                            property real calm: toast.notif.holds > 0 ? 0 : 1

                            Behavior on calm {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }

                            x: content.x
                            y: parent.height - toast.padding / 2 - height + 2
                            width: Math.max(0, content.width * toast.remaining)
                            height: 10

                            lineWidth: 3
                            amplitudeMultiplier: calm * 0.9
                            frequency: 14
                            fullLength: content.width
                            value: 1

                            color: toast.notif.critical ? Appearance.palette.m3error : Appearance.palette.m3primary
                            opacity: 0.85

                            NumberAnimation on waveProgress {
                                running: wave.visible && wave.calm > 0
                                from: 0
                                to: 1
                                duration: 1400
                                loops: Animation.Infinite
                            }
                        }
                    }
                }
            }
        }
    }
}
