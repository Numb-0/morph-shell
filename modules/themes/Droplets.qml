pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Morph.Blobs
import qs.components
import qs.config
import qs.services.session

// The switcher itself: a row of drops, one per theme, each a bead of
// surface holding a disc of the theme's primary; a bubble above with the
// preview in it; a stem joining the bubble to the drop being looked at;
// and a pill below for light and dark. All of it one blob group, so the
// beads neck into each other like the workspaces' drops, the stem flares
// into the bubble and the drop it hangs from, and the whole switcher
// reads as one body of liquid.
//
// The drops keep fixed slots, the one being looked at only swelling in
// its own, so nothing moves out from under the pointer as it goes along
// the row. The stem slides between them on a slower spring than the
// drops swell on, dragging a little behind.
Item {
    id: root

    required property ThemePicker picker
    required property ShellScreen screen

    readonly property ThemePalette tones: picker.tones

    readonly property var themes: Themes.themes
    readonly property int count: themes.length

    readonly property int focusIndex: themes.findIndex(t => t.name === picker.previewed)
    readonly property int chosenIndex: themes.findIndex(t => t.name === picker.picked)

    readonly property int bubbleWidth: 620
    readonly property int bubbleHeight: 360
    readonly property int stemWidth: 22
    readonly property int stemGap: 44
    readonly property int dropSize: 46
    readonly property int focusSize: 68
    readonly property int pillHeight: 52
    readonly property int pillGap: 30

    // Each drop's slot, the size of a swollen drop, so a drop at rest
    // sits clear of its neighbours by a little less than the group's
    // smoothing and necks into them.
    readonly property int slot: focusSize

    readonly property real rowCy: bubbleHeight + stemGap + focusSize / 2
    readonly property real pillTop: rowCy + focusSize / 2 + pillGap

    // How far the bubble has grown out of the stem, how far the stem has
    // reached up out of the drop, and how far the pill has swollen.
    property real grow: 0
    property real stem: 0
    property real pillShown: 0

    // 0 to 1 after the look moves to another drop: the bubble jiggles as
    // the stem tugs it, wide then tall, losing a little each time.
    property real wobble: 1
    readonly property real jiggle: wobble < 1 ? 0.03 * Math.exp(-4 * wobble) * Math.sin(wobble * 6 * Math.PI) : 0

    // Where the stem hangs, sliding after the drop being looked at.
    property real stemX: centre(Math.max(0, focusIndex))

    Behavior on stemX {
        Anim {
            type: Anim.SlowSpatial
        }
    }

    onFocusIndexChanged: {
        if (grow > 0.9)
            jiggleAnim.restart();
    }

    function centre(i: int): real {
        return width / 2 + (i - (count - 1) / 2) * slot;
    }

    // A drop's centre in global coordinates, where its flood grows from.
    function globalCentre(i: int): point {
        const p = mapToItem(null, centre(i), rowCy);
        return Qt.point(screen.x + p.x, screen.y + p.y);
    }

    function applyAt(i: int): void {
        if (i < 0 || i >= count)
            return;
        picker.apply(themes[i].name, globalCentre(i));
    }

    function move(d: int): void {
        if (count === 0 || picker.committing)
            return;
        const i = ((Math.max(0, chosenIndex) + d) % count + count) % count;
        // The keyboard takes over from the pointer until it moves again.
        picker.hovered = "";
        picker.picked = themes[i].name;
    }

    function flipMode(): void {
        picker.pickedMode = picker.pickedMode === "light" ? "dark" : "light";
    }

    width: Math.max(bubbleWidth, count * slot) + Appearance.padding.extraLarge * 2
    height: pillTop + pillHeight

    // Handed over to the flood as it starts, which grows out of the
    // chosen drop at exactly its size and colour. Left drawn, the drop
    // would sit under the flood's own and show, still, as that one
    // shrinks away at the end, until the window unloaded it.
    visible: !picker.flooding

    focus: true

    Component.onCompleted: {
        forceActiveFocus();
        appear.start();
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            break;
        case Qt.Key_Right:
            move(1);
            break;
        case Qt.Key_Tab:
        case Qt.Key_Up:
        case Qt.Key_Down:
            flipMode();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            applyAt(chosenIndex);
            break;
        case Qt.Key_Escape:
            picker.close();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // In: the drops pop up along the row (each on its own, below), the
    // stem reaches up out of the one being looked at, and the bubble
    // swells out of the top of the stem.
    ParallelAnimation {
        id: appear

        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }
            Anim {
                target: root
                property: "stem"
                to: 1
                type: Anim.FastSpatial
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 220
            }
            Anim {
                target: root
                property: "grow"
                to: 1
                type: Anim.DefaultSpatial
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 300
            }
            Anim {
                target: root
                property: "pillShown"
                to: 1
                type: Anim.FastSpatial
            }
        }
    }

    // Out, or into the chosen drop on an Apply: the bubble draws back
    // into the stem and the stem into the drop.
    ParallelAnimation {
        id: disappear

        Anim {
            target: root
            property: "grow"
            to: 0
            type: Anim.Standard
            duration: 260
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }
            Anim {
                target: root
                property: "stem"
                to: 0
                type: Anim.Standard
                duration: 200
            }
        }

        Anim {
            target: root
            property: "pillShown"
            to: 0
            type: Anim.Standard
            duration: 220
        }
    }

    Connections {
        target: root.picker

        function onShownChanged(): void {
            if (!root.picker.shown) {
                appear.stop();
                disappear.restart();
            }
        }
    }

    NumberAnimation {
        id: jiggleAnim

        target: root
        property: "wobble"
        from: 0
        to: 1
        duration: 700
    }

    // Not called group: inside a delegate that name finds the shape's
    // own group property before it finds this, and the shape is never
    // drawn.
    // A step up from the bar's surfaceContainer: over the dim, that
    // nearly vanishes on a dark theme and the liquid stops reading as
    // one shape.
    BlobGroup {
        id: body

        color: root.tones.m3surfaceContainerHigh
        smoothing: Appearance.border.smoothing
    }

    // The bubble. Grows out of the top of the stem, wherever along the
    // row that is, and settles in the middle.
    BlobRect {
        id: bubble

        readonly property real fullWidth: root.bubbleWidth * (1 + root.jiggle)
        readonly property real fullHeight: root.bubbleHeight * (1 - root.jiggle)

        group: root.grow > 0.01 ? body : null

        width: root.stemWidth + (fullWidth - root.stemWidth) * root.grow
        height: root.stemWidth + (fullHeight - root.stemWidth) * root.grow
        x: root.stemX + (root.width / 2 - root.stemX) * Math.min(1, root.grow) - width / 2
        y: root.bubbleHeight - height

        radius: Math.min(Appearance.rounding.extraLarge + 8, width / 2, height / 2)
        deformScale: 0

        // Keeps a click on the bubble from reaching the dim, which
        // would close.
        MouseArea {
            anchors.fill: parent
        }

        ThemePreview {
            anchors.fill: parent
            anchors.margins: Appearance.padding.medium

            radius: Appearance.rounding.extraLarge - 4
            opacity: Math.max(0, (root.grow - 0.6) / 0.4)

            tones: root.tones
            wallpaper: root.picker.previewInfo?.wallpaper ?? ""
            title: root.picker.displayName(root.picker.previewed)
            subtitle: {
                const p = root.picker;
                const mode = p.pickedMode === "light" ? qsTr("Light") : qsTr("Dark");
                return p.previewed === Themes.theme && p.pickedMode === Themes.mode ? qsTr("%1 · in use").arg(mode) : mode;
            }
        }
    }

    // The stem, from the middle of the drop being looked at up into the
    // bubble's lower edge. Anchored at the drop, so it reaches up out of
    // it on the way in and is drawn back down into it on the way out.
    BlobRect {
        group: root.stem > 0.01 && root.focusIndex >= 0 ? body : null

        x: root.stemX - width / 2
        y: root.rowCy - height
        width: root.stemWidth
        height: (root.stemGap + root.stemWidth + root.focusSize / 2) * root.stem
        radius: root.stemWidth / 2
    }

    Repeater {
        model: root.themes

        BlobRect {
            id: drop

            required property var modelData
            required property int index

            readonly property string name: modelData.name
            readonly property var colors: root.picker.infoFor(name)?.colors ?? ({})

            readonly property bool focused: index === root.focusIndex
            readonly property bool current: name === Themes.theme
            readonly property bool chosen: root.picker.committing && index === root.chosenIndex

            // On an Apply the others draw into the chosen drop and shrink
            // away in it, and it swells to the size the flood grows from.
            property real diameter: root.picker.committing ? (chosen ? root.picker.dropRadius * 2 : 0) : focused ? root.focusSize : root.dropSize
            property real shown: 0
            property real at: root.picker.committing ? root.centre(root.chosenIndex) : root.centre(index)

            Behavior on diameter {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on at {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            group: width > 0.5 ? body : null

            x: at - width / 2
            y: root.rowCy - height / 2
            width: diameter * shown
            height: diameter * shown
            radius: width / 2
            deformScale: 0

            // Popping up along the row in turn on the way in, and back
            // down together on the way out.
            Component.onCompleted: popIn.start()

            SequentialAnimation {
                id: popIn

                PauseAnimation {
                    duration: 40 * drop.index
                }
                Anim {
                    target: drop
                    property: "shown"
                    to: 1
                    type: Anim.FastSpatial
                }
            }

            Connections {
                target: root.picker

                function onShownChanged(): void {
                    if (!root.picker.shown && !root.picker.committing) {
                        popIn.stop();
                        popOut.restart();
                    }
                }
            }

            Anim {
                id: popOut

                target: drop
                property: "shown"
                to: 0
                type: Anim.Standard
                duration: 220
            }

            // The theme's primary, ringed in the surface the drop is
            // made of. The chosen one fills to the edge as it swells, so
            // the flood that grows out of it starts as all primary.
            Rectangle {
                anchors.centerIn: parent

                width: drop.chosen ? parent.width : Math.max(0, parent.width - (drop.focused ? 20 : 16))
                height: width
                radius: width / 2

                color: drop.colors.primary ?? root.tones.m3primary

                Behavior on width {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent

                    visible: drop.current && !root.picker.committing

                    icon: "check"
                    size: drop.focused ? Appearance.font.icon.normal : Appearance.font.icon.small
                    weight: 600
                    color: drop.colors.onPrimary ?? root.tones.m3onPrimary
                }
            }
        }
    }

    // The drops' hit areas: their slots, fixed, so swelling never moves
    // a drop out from under the pointer.
    Repeater {
        model: root.themes

        Item {
            id: hit

            required property var modelData
            required property int index

            x: root.centre(index) - width / 2
            y: root.rowCy - height / 2
            width: root.slot
            height: root.focusSize

            HoverHandler {
                cursorShape: Qt.PointingHandCursor

                onHoveredChanged: {
                    if (root.picker.committing)
                        return;
                    if (hovered)
                        root.picker.hovered = hit.modelData.name;
                    else if (root.picker.hovered === hit.modelData.name)
                        root.picker.hovered = "";
                }
            }

            TapHandler {
                onTapped: root.applyAt(hit.index)
            }
        }
    }

    // Light and dark, on a pill of the same liquid below the row.
    BlobRect {
        group: root.pillShown > 0.01 ? body : null

        readonly property real fullWidth: modes.implicitWidth + Appearance.padding.small * 2

        width: fullWidth * root.pillShown
        height: root.pillHeight * root.pillShown
        x: (root.width - width) / 2
        y: root.pillTop + (root.pillHeight - height) / 2
        radius: height / 2
        deformScale: 0

        ModeSegments {
            id: modes

            anchors.centerIn: parent

            opacity: root.pillShown
            border.width: 0

            tones: root.tones
            mode: root.picker.pickedMode

            onPicked: mode => root.picker.pickedMode = mode
        }
    }
}
