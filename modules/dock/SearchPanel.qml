import QtQuick
import Quickshell
import qs.components
import qs.config

// What the dock grows into, whichever panel it is: a search field over
// a list of results. The launcher and the clipboard each hand it their
// results and a row to draw them with, and say what Enter does. The
// emoji panel asks for a grid instead, by giving it columns.
Item {
    id: root

    // Driven by the dock. Opening resets the field, so a panel always
    // opens on everything rather than on the last search.
    property bool active: false

    readonly property string query: search.text
    property string placeholder
    property string emptyText

    // The glyph at the head of the field.
    property string icon: "search"

    property var results: []
    property Component delegate

    // More than one lays the results out in a grid of square cells,
    // this many to a row, rather than in a list.
    property int columns: 1
    readonly property bool grid: columns > 1

    // Mirrors the selection of whichever view is showing, both ways:
    // the view moves its own when rows are inserted above it, and the
    // panels move it on hover.
    property int currentIndex: 0

    readonly property var view: grid ? gridView : list

    onCurrentIndexChanged: if (view.currentIndex !== currentIndex)
        view.currentIndex = currentIndex

    // What sort of results these are. A panel that lists more than one
    // sort -- the launcher's applications and its commands -- names
    // which, and a change of it swaps the whole list over rather than
    // reshuffling one sort's rows into the other's.
    property string kind

    // What the list is drawing, which trails the above through a swap:
    // the old rows sink away, and the new ones come up in their place
    // once they are out of sight.
    property var shownResults: []
    property Component shownDelegate
    property string shownEmptyText
    property string shownIcon: icon

    readonly property var current: results[currentIndex] ?? null

    // Anything else the field carries, after the text.
    property alias actions: actionRow.data

    signal dismissed
    signal accepted(var result)

    // Shift+Delete, so plain Delete still edits the search.
    signal removeRequested(var result)

    function reset(): void {
        search.text = "";
        currentIndex = 0;
    }

    // The arrows step a row at a time, which in a grid is a row of
    // cells; Left and Right step a cell, there being no text to move
    // through that a search of a word or two needs them for.
    function step(by: int): void {
        const last = shownResults.length - 1;
        const next = currentIndex + by;

        if (next >= 0 && next <= last)
            currentIndex = next;
        // Down from the row above a short last one lands on its end.
        else if (by > 1 && Math.floor(currentIndex / columns) < Math.floor(last / columns))
            currentIndex = last;
    }

    // Hands the list its new rows. Emptied in between, so for no frame
    // does a row of one sort get handed a result of the other.
    function applyKind(): void {
        shownResults = [];
        shownDelegate = delegate;
        shownEmptyText = emptyText;
        shownResults = results;
    }

    // Catches the list up with the results, unless a swap is holding the
    // old ones on screen. A beat late, because the kind, the results and
    // the row all change off the same keystroke in no promised order:
    // by then the swap, if there is one, has started.
    function follow(): void {
        if (swap.running)
            return;

        if (shownDelegate !== delegate) {
            applyKind();
        } else {
            shownResults = results;
            shownEmptyText = emptyText;
        }
    }

    onResultsChanged: Qt.callLater(root.follow)
    onDelegateChanged: Qt.callLater(root.follow)
    onEmptyTextChanged: Qt.callLater(root.follow)

    Component.onCompleted: applyKind()

    // Set while opening resets the field, when the panel is still
    // hidden and a swap would only hold the list back.
    property bool settling: false

    onKindChanged: {
        if (active && !settling) {
            swap.restart();
        } else {
            swap.stop();
            page.opacity = 1;
            pageShift.y = 0;
        }
    }

    onIconChanged: {
        if (active && !settling) {
            iconSwap.restart();
        } else {
            iconSwap.stop();
            searchIcon.scale = 1;
            searchIcon.opacity = 1;
            shownIcon = icon;
        }
    }

    // Out quick and low, in with the emphasized curve rising back to
    // place: the list reads as replaced rather than as re-sorted.
    SequentialAnimation {
        id: swap

        ParallelAnimation {
            Anim {
                target: page
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                target: pageShift
                property: "y"
                to: Appearance.spacing.large
                type: Anim.FastEffects
            }
        }

        ScriptAction {
            script: {
                root.applyKind();
                pageShift.y = -Appearance.spacing.large;
            }
        }

        ParallelAnimation {
            Anim {
                target: page
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
            Anim {
                target: pageShift
                property: "y"
                to: 0
                type: Anim.Emphasized
            }
        }
    }

    // The glyph shrinks away and the new one grows back in its place.
    SequentialAnimation {
        id: iconSwap

        ParallelAnimation {
            Anim {
                target: searchIcon
                property: "scale"
                to: 0.5
                type: Anim.FastEffects
            }
            Anim {
                target: searchIcon
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
        }

        ScriptAction {
            script: root.shownIcon = root.icon
        }

        ParallelAnimation {
            Anim {
                target: searchIcon
                property: "scale"
                to: 1
                type: Anim.FastSpatial
            }
            Anim {
                target: searchIcon
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    function grabFocus(): void {
        search.forceActiveFocus();
    }

    // The field and the list arrive once the dock shape has grown
    // enough to show them -- any sooner and their fades play out behind
    // its clip, unseen -- the field a step ahead of the list, which also
    // rises into place. Closing fades both straight away.
    //
    // States rather than Behaviors: a Behavior's pause bound to `active`
    // would still hold the previous value when the animation starts,
    // giving opening the closing delay and the other way round.
    states: State {
        name: "open"
        when: root.active

        PropertyChanges {
            field.opacity: 1
            views.opacity: 1
            listShift.y: 0
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
                        target: field
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
                            target: views
                            property: "opacity"
                            type: Anim.SlowEffects
                        }
                        Anim {
                            target: listShift
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
                targets: [field, views]
                property: "opacity"
                type: Anim.FastEffects
            }
            Anim {
                target: listShift
                property: "y"
                type: Anim.FastEffects
            }
        }
    ]

    // The focus waits a beat: the dock enables the panel off the same
    // change that makes it active, and a disabled item cannot take the
    // keyboard, so asking straight away could land before it is enabled.
    // A new search starts from the top of its own results rather than
    // from wherever the last one had got to. A beat later, once the
    // model has taken the new results: it diffs them into the old rows,
    // and the list's selection follows its row through every insert
    // and move -- a top result that lands at the bottom of the new
    // results would carry the selection down with it.
    //
    // Off what the list shows rather than the results themselves, so a
    // swap's held rows are not reset under it.
    onShownResultsChanged: Qt.callLater(() => {
        root.currentIndex = 0;
        root.view.currentIndex = 0;
    })

    onActiveChanged: {
        if (active) {
            settling = true;
            reset();
            settling = false;
            Qt.callLater(grabFocus);
        }
    }

    // The field. A plain TextInput rather than a Controls TextField: the
    // shell styles everything itself, and a TextField would arrive with
    // a theme's own background to undo.
    Rectangle {
        id: field

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: Appearance.dock.resultHeight

        radius: height / 2
        color: Appearance.palette.m3surfaceContainerHighest

        // Closed until the open state says otherwise.
        opacity: 0

        Row {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: actionRow.visible ? Appearance.padding.small : Appearance.padding.large
            spacing: Appearance.spacing.small

            MaterialSymbol {
                id: searchIcon

                anchors.verticalCenter: parent.verticalCenter

                icon: root.shownIcon
                size: Appearance.font.icon.normal
                color: Appearance.palette.m3onSurfaceVariant
            }

            TextInput {
                id: search

                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - searchIcon.width - parent.spacing - (actionRow.visible ? actionRow.width + parent.spacing : 0)

                color: Appearance.palette.m3onSurface
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.normal

                renderType: TextInput.NativeRendering
                selectByMouse: true
                selectionColor: Appearance.palette.m3primary
                selectedTextColor: Appearance.palette.m3onPrimary

                // The list never takes focus -- the field keeps it and
                // drives the selection -- so typing continues to work
                // while arrowing through results.
                Keys.onDownPressed: root.step(root.columns)
                Keys.onUpPressed: root.step(-root.columns)
                Keys.onLeftPressed: event => {
                    if (root.grid)
                        root.step(-1);
                    else
                        event.accepted = false;
                }
                Keys.onRightPressed: event => {
                    if (root.grid)
                        root.step(1);
                    else
                        event.accepted = false;
                }
                Keys.onEscapePressed: root.dismissed()
                Keys.onReturnPressed: root.accepted(root.current)
                Keys.onEnterPressed: root.accepted(root.current)
                Keys.onDeletePressed: event => {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.removeRequested(root.current);
                    else
                        event.accepted = false;
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: search.text.length === 0

                    text: root.placeholder
                    font.pixelSize: Appearance.font.normal
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }

            Row {
                id: actionRow

                anchors.verticalCenter: parent.verticalCenter

                visible: children.length > 0
                spacing: Appearance.spacing.extraSmall
            }
        }
    }

    // Carries a swap from one sort of results to the other, apart from
    // the opening and closing the list itself carries.
    Item {
        id: page

        anchors.top: field.bottom
        anchors.topMargin: Appearance.spacing.small
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        transform: Translate {
            id: pageShift
        }

        // Opens and closes both views, whichever is showing: closed, and
        // sunk a little, until the open state says otherwise.
        Item {
            id: views

            anchors.fill: parent

            opacity: 0

            // Driven by the open state above.
            transform: Translate {
                id: listShift

                y: Appearance.spacing.large * 2
            }

            ListView {
                id: list

                anchors.fill: parent

                visible: !root.grid
                clip: true
                spacing: Appearance.spacing.extraSmall

                model: ScriptModel {
                    values: root.grid ? [] : root.shownResults
                }

                delegate: root.shownDelegate

                onCurrentIndexChanged: if (!root.grid && root.currentIndex !== currentIndex)
                    root.currentIndex = currentIndex

                // Keeps the selection on screen as the arrows walk past the
                // bottom of the view.
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Appearance.anim.durations.fastEffects

                // Rows fade and slide rather than popping as the search
                // narrows or widens the results; the rest close ranks smoothly.
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
                        property: "y"
                        type: Anim.Emphasized
                    }
                    // Brings back a row whose own add or remove was cut short.
                    Anim {
                        properties: "opacity,scale"
                        to: 1
                        type: Anim.DefaultEffects
                    }
                }

                highlight: Rectangle {
                    radius: Appearance.rounding.large
                    color: Appearance.palette.m3surfaceContainerHigh
                }
            }

            // The same, in square cells. Cells only fade: a grid reflowing
            // under a search moves too much at once for each to slide too.
            GridView {
                id: gridView

                anchors.fill: parent

                visible: root.grid
                clip: true

                // As near square as a whole number of rows allows: the rows
                // fill the view exactly, so none is left cut off at the
                // bottom, and scrolling snaps a whole row at a time.
                cellWidth: Math.floor(width / Math.max(1, root.columns))
                cellHeight: height / Math.max(1, Math.round(height / cellWidth))

                snapMode: GridView.SnapToRow

                model: ScriptModel {
                    values: root.grid ? root.shownResults : []
                }

                delegate: root.shownDelegate

                onCurrentIndexChanged: if (root.grid && root.currentIndex !== currentIndex)
                    root.currentIndex = currentIndex

                highlightRangeMode: GridView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Appearance.anim.durations.fastEffects

                add: Transition {
                    Anim {
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.DefaultEffects
                    }
                    Anim {
                        property: "scale"
                        from: 0.6
                        to: 1
                        type: Anim.FastSpatial
                    }
                }

                remove: Transition {
                    Anim {
                        property: "opacity"
                        to: 0
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

                highlight: Rectangle {
                    radius: Appearance.rounding.medium
                    color: Appearance.palette.m3surfaceContainerHigh
                }
            }

            StyledText {
                anchors.centerIn: parent

                visible: root.shownResults.length === 0

                text: root.shownEmptyText
                color: Appearance.palette.m3onSurfaceVariant
            }
        }
    }
}
