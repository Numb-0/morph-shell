import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// What the dock grows into when a pinned app has more than one window
// open: a live picture of each, to pick the one to go to rather than
// cycling through them blind. Picking one focuses it and puts the panel
// away; a middle click closes that window instead.
Item {
    id: root

    // Driven by the dock, as the other panels are.
    property bool active: false

    // The app whose windows these are. Kept by the dock after the panel
    // closes, so the cards fade out with what they were showing.
    property DesktopEntry entry: null

    readonly property var windows: Apps.windowsFor(entry)

    readonly property int columns: Appearance.dock.chooserColumns
    readonly property int rows: Math.max(1, Math.min(Appearance.dock.chooserRows, Math.ceil(windows.length / columns)))
    readonly property int cardHeight: Appearance.dock.previewHeight + Appearance.dock.cardTitleHeight

    // As tall as the rows it has, and no more: the dock grows only to
    // fit, so two windows make a short panel rather than a launcher-sized
    // one with a hole in it. Whole cells, gap under the last row
    // included, so every scroll position the view can reach is a row's
    // start: a view a gap short of that leaves its bottom-most position
    // between rows, and the snapping fights it.
    implicitHeight: header.implicitHeight + Appearance.spacing.small + rows * (cardHeight + Appearance.spacing.small)

    signal dismissed

    function pick(toplevel: var): void {
        if (!toplevel)
            return;

        toplevel.activate();
        root.dismissed();
    }

    // Starts on the window after the focused one, as a repeat click on
    // the icon used to cycle to, so Enter alone does what it did.
    function preselect(): void {
        const current = windows.indexOf(ToplevelManager.activeToplevel);
        selection.animate = false;
        grid.currentIndex = current < 0 ? 0 : (current + 1) % windows.length;
        grid.reveal(false);
        Qt.callLater(() => selection.animate = true);
    }

    // Left and right run through the windows in order, wrapping at
    // either end, rather than stopping at the edge of a row.
    function step(by: int): void {
        const n = windows.length;
        if (n > 0)
            grid.currentIndex = (grid.currentIndex + by + n) % n;
    }

    // Up and down keep to the column, and wrap top to bottom. A last row
    // short of that column is still landed on, on its last window: the
    // view's own Down skips it and wraps to the top instead.
    function stepRow(by: int): void {
        const n = windows.length;
        if (n === 0)
            return;

        const index = grid.currentIndex;
        const column = index % columns;
        const lastRow = Math.floor((n - 1) / columns);
        const row = Math.floor(index / columns) + by;

        if (row < 0)
            grid.currentIndex = Math.min(n - 1, lastRow * columns + column);
        else if (row > lastRow)
            grid.currentIndex = column;
        else
            grid.currentIndex = Math.min(n - 1, row * columns + column);
    }

    onActiveChanged: if (active) {
        preselect();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    // Another app's icon clicked while the panel is up swaps it over
    // where it stands.
    onEntryChanged: if (active)
        preselect()

    // Its last window closed under it: nothing left to choose.
    onWindowsChanged: if (active && windows.length === 0)
        root.dismissed()

    // Holds the keyboard for the arrows: there is no field to type in.
    Item {
        id: keys

        Keys.onLeftPressed: root.step(-1)
        Keys.onRightPressed: root.step(1)
        Keys.onUpPressed: root.stepRow(-1)
        Keys.onDownPressed: root.stepRow(1)
        Keys.onTabPressed: root.step(1)
        Keys.onBacktabPressed: root.step(-1)
        Keys.onEscapePressed: root.dismissed()
        Keys.onReturnPressed: root.pick(root.windows[grid.currentIndex])
        Keys.onEnterPressed: root.pick(root.windows[grid.currentIndex])
        Keys.onDeletePressed: root.windows[grid.currentIndex]?.close()
    }

    // The same arrival as the search panels': the header a step ahead of
    // the cards, which also rise into place.
    states: State {
        name: "open"
        when: root.active

        PropertyChanges {
            header.opacity: 1
            grid.opacity: 1
            gridShift.y: 0
        }
    }

    transitions: [
        Transition {
            to: "open"

            ParallelAnimation {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Appearance.anim.durations.fastEffects
                    }
                    Anim {
                        target: header
                        property: "opacity"
                        type: Anim.SlowEffects
                    }
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: Appearance.anim.durations.slowEffects
                    }
                    ParallelAnimation {
                        Anim {
                            target: grid
                            property: "opacity"
                            type: Anim.SlowEffects
                        }
                        Anim {
                            target: gridShift
                            property: "y"
                            type: Anim.Emphasized
                        }
                    }
                }
            }
        },
        Transition {
            from: "open"

            Anim {
                targets: [header, grid]
                property: "opacity"
                type: Anim.FastEffects
            }
            Anim {
                target: gridShift
                property: "y"
                type: Anim.FastEffects
            }
        }
    ]

    // Which app, and how many of it: the pill the search field is in the
    // other panels, so the dock keeps one face whichever it has become.
    Rectangle {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: Appearance.dock.resultHeight

        radius: height / 2
        color: Appearance.palette.m3surfaceContainerHighest

        opacity: 0

        Row {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.medium
            anchors.rightMargin: Appearance.padding.large
            spacing: Appearance.spacing.small

            IconImage {
                id: headerIcon

                anchors.verticalCenter: parent.verticalCenter

                implicitSize: Appearance.font.icon.large
                source: Quickshell.iconPath(root.entry?.icon ?? "", "application-x-executable")
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - headerIcon.width - countLabel.width - parent.spacing * 2

                text: root.entry?.name ?? ""
                font.pixelSize: Appearance.font.normal
                elide: Text.ElideRight
            }

            StyledText {
                id: countLabel

                anchors.verticalCenter: parent.verticalCenter

                text: root.windows.length === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(root.windows.length)
                color: Appearance.palette.m3onSurfaceVariant
            }
        }
    }

    GridView {
        id: grid

        anchors.top: header.bottom
        anchors.topMargin: Appearance.spacing.small
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        clip: true
        opacity: 0

        // The gap between cards rides inside each cell; the last row's
        // stands in for the gap above the dock's icons.
        cellWidth: width / root.columns
        cellHeight: root.cardHeight + Appearance.spacing.small

        // Rests on whole rows, however it is scrolled: a drag settles on
        // the nearest, and the wheel steps one row a notch.
        snapMode: GridView.SnapToRow
        boundsBehavior: Flickable.StopAtBounds

        // The view's own highlight slides its box while the card's inset
        // inside it snaps, which jerks every move across a column; the
        // selection further down follows the card itself instead.
        highlightFollowsCurrentItem: false

        readonly property real maxScroll: Math.max(0, contentHeight - height)

        // Scrolling by any means. Cards slide under a pointer that has
        // not moved meanwhile, which is no reason to select them.
        readonly property bool scrolling: moving || scroll.running

        // The card under a point in the view's own coordinates with the
        // view scrolled to scrollY, if one is wholly in sight there: a
        // row half scrolled out, or one only built ahead of time below
        // the clip, is not offered. Worked out from the cells rather than
        // asked of the view, so it can answer for where a scroll is
        // going as well as for where it is.
        function cardAt(pos: point, scrollY: real): int {
            if (pos.x < 0 || pos.y < 0 || pos.x >= width || pos.y >= height)
                return -1;

            const row = Math.floor((pos.y + scrollY) / cellHeight);
            const index = row * root.columns + Math.floor(pos.x / cellWidth);
            if (index >= count)
                return -1;

            const top = row * cellHeight - scrollY;
            return top >= -1 && top + root.cardHeight <= height + 1 ? index : -1;
        }

        // The card under the pointer, read fresh rather than kept, since
        // the view may have scrolled under it since it last moved.
        function pointedIndex(scrollY: real): int {
            return pointer.hovered ? cardAt(mapFromItem(null, pointer.point.scenePosition), scrollY) : -1;
        }

        // Dragged or flicked rather than stepped: where it comes to rest
        // is only known once it does, and the selection follows then.
        property bool flicked: false

        onMovementStarted: flicked = true

        onMovementEnded: if (flicked) {
            flicked = false;
            follow(Math.round(contentY / cellHeight));
        }

        // Picks the card under the pointer, or failing that the nearest
        // visible one in the selection's column, so the selection never
        // sits on a row the view has scrolled away from.
        function follow(first: int): void {
            const row = Math.floor(currentIndex / root.columns);

            if (row >= first && row < first + root.rows)
                return;

            const pointed = pointedIndex(first * cellHeight);
            if (pointed >= 0) {
                currentIndex = pointed;
                return;
            }

            const target = Math.max(first, Math.min(first + root.rows - 1, row));
            currentIndex = Math.min(grid.count - 1, target * root.columns + currentIndex % root.columns);
        }

        // By the wheel, the selection is sent to the rows coming into
        // view as the scroll starts, so the two travel together rather
        // than the selection being carried off and fetched back. Sent
        // after the scroll is under way, so the reveal the new selection
        // asks for sees where the view is going and has nothing to do.
        function scrollToRow(row: int, animated: bool, byHand: bool): void {
            const target = Math.max(0, Math.min(maxScroll, row * cellHeight));
            scroll.stop();
            if (animated && target !== contentY) {
                scroll.to = target;
                scroll.start();
            } else {
                contentY = target;
            }

            if (byHand)
                follow(Math.round(target / cellHeight));
        }

        // Brings the selection's row into view, by as few rows as it
        // takes, when the arrows walk it off the top or the bottom.
        function reveal(animated: bool): void {
            if (currentIndex < 0)
                return;

            const row = Math.floor(currentIndex / root.columns);
            const first = Math.round((scroll.running ? scroll.to : contentY) / cellHeight);

            if (row < first)
                scrollToRow(row, animated, false);
            else if (row >= first + root.rows)
                scrollToRow(row - root.rows + 1, animated, false);
            else if (!animated)
                scrollToRow(first, false, false);
        }

        // The arrows, Tab, or the pointer: whatever moved the selection,
        // its row is brought into view. A drag or a flick still running
        // gives way to it rather than carrying the view off elsewhere.
        onCurrentIndexChanged: {
            if (moving)
                cancelFlick();
            reveal(true);
        }

        // Selects what the pointer moves onto, and only when it moves:
        // a card scrolled under a pointer at rest, or one that comes back
        // into reach there, is no reason to take the selection from the
        // arrows. Hover reaches a handler again whenever what is under it
        // changes, so the pointer's place on screen is compared instead.
        HoverHandler {
            id: pointer

            property point last: Qt.point(-1, -1)

            onPointChanged: {
                const at = point.scenePosition;
                if (at.x === last.x && at.y === last.y)
                    return;
                last = at;

                if (grid.scrolling)
                    return;

                const index = grid.cardAt(grid.mapFromItem(null, at), grid.contentY);
                if (index >= 0)
                    grid.currentIndex = index;
            }

            onHoveredChanged: if (!hovered)
                last = Qt.point(-1, -1)
        }

        Anim {
            id: scroll

            target: grid
            property: "contentY"
            type: Anim.Emphasized
        }

        // A mouse notch, or a touchpad's worth of one, is a row. Taken
        // here rather than left to the view, whose own wheel scrolling
        // glides by pixels and only snaps once it stops.
        WheelHandler {
            property real pending: 0

            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                pending += event.angleDelta.y;
                if (Math.abs(pending) < 120)
                    return;

                const step = pending > 0 ? -1 : 1;
                pending = 0;

                const first = Math.round((scroll.running ? scroll.to : grid.contentY) / grid.cellHeight);
                grid.scrollToRow(first + step, true, true);
            }
        }

        model: ScriptModel {
            values: root.windows
        }

        transform: Translate {
            id: gridShift

            y: Appearance.spacing.large * 2
        }

        // Cards fade and grow in and out as windows come and go while the
        // panel is up; the rest close ranks.
        add: Transition {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
            Anim {
                property: "scale"
                from: 0.9
                to: 1
                type: Anim.Emphasized
            }
        }

        remove: Transition {
            Anim {
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                property: "scale"
                to: 0.9
                type: Anim.FastEffects
            }
        }

        displaced: Transition {
            Anim {
                properties: "x,y"
                type: Anim.Emphasized
            }
            Anim {
                properties: "opacity,scale"
                to: 1
                type: Anim.DefaultEffects
            }
        }

        // Rides under the selected card, on one curve for both axes so a
        // diagonal move is one movement rather than two. Placed in the
        // view's content by hand, so it scrolls with the cards: a view
        // keeps what is declared in it on itself, unlike a plain
        // Flickable, and left there it would sit still while the cards
        // scrolled away from it.
        Rectangle {
            id: selection

            parent: grid.contentItem

            // Off while the panel opens or swaps apps, so the selection
            // lands on its card rather than flying in from the last one.
            property bool animate: false

            readonly property Item target: grid.currentItem?.card ?? null

            z: -1
            visible: target !== null

            x: target ? grid.currentItem.x + target.x : 0
            y: target ? grid.currentItem.y + target.y : 0
            width: target?.width ?? 0
            height: target?.height ?? 0

            radius: Appearance.rounding.large
            color: Appearance.palette.m3surfaceContainerHigh

            Behavior on x {
                enabled: selection.animate

                Anim {
                    type: Anim.Emphasized
                }
            }

            Behavior on y {
                enabled: selection.animate

                Anim {
                    type: Anim.Emphasized
                }
            }
        }

        delegate: Item {
            id: cell

            required property int index
            required property var modelData

            readonly property bool focused: modelData?.activated ?? false
            property alias card: card

            width: grid.cellWidth
            height: grid.cellHeight

            Item {
                id: card

                // Half the gap on the side that faces the neighbour, so
                // both columns come out the same width.
                x: cell.index % root.columns === 0 ? 0 : Appearance.spacing.small / 2
                width: parent.width - Appearance.spacing.small / 2
                height: root.cardHeight

                // Wholly inside the view. The view builds the rows just out
                // of sight ahead of time, and its clip hides them without
                // keeping the pointer from them: one below the last
                // visible row sits under the dock's own icons, and would
                // take their hover and their clicks.
                readonly property bool inView: {
                    const top = cell.y - grid.contentY;
                    return top >= -1 && top + root.cardHeight <= grid.height + 1;
                }

                // The cursor only: selecting by pointing is the view's,
                // which can tell a pointer moving from cards moving under
                // it.
                HoverHandler {
                    enabled: card.inView
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: card.inView

                    onTapped: root.pick(cell.modelData)
                }

                TapHandler {
                    enabled: card.inView
                    acceptedButtons: Qt.MiddleButton

                    onTapped: cell.modelData?.close()
                }

                ClippingRectangle {
                    id: preview

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Appearance.padding.small

                    height: Appearance.dock.previewHeight - Appearance.padding.small

                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3surfaceContainerHighest

                    // The focused window is ringed, so the one you are
                    // already on is told apart from the one to go to.
                    border.width: cell.focused ? 2 : 0
                    border.color: Appearance.palette.m3primary

                    // Captured only while the panel is up: a live copy of
                    // every window kept running behind a closed dock would
                    // cost for nothing.
                    ScreencopyView {
                        id: view

                        anchors.fill: parent
                        anchors.margins: preview.border.width

                        captureSource: root.active ? cell.modelData : null
                        live: root.active
                    }

                    // The app's icon stands in until the first frame
                    // arrives, and for a window that cannot be captured.
                    IconImage {
                        anchors.centerIn: parent

                        visible: !view.hasContent
                        implicitSize: Appearance.font.icon.large * 1.5
                        source: Quickshell.iconPath(root.entry?.icon ?? "", "application-x-executable")
                        asynchronous: true
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Appearance.padding.medium
                    anchors.rightMargin: Appearance.padding.medium

                    height: Appearance.dock.cardTitleHeight
                    verticalAlignment: Text.AlignVCenter

                    text: cell.modelData?.title || root.entry?.name || ""
                    color: cell.focused ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }
        }
    }
}
