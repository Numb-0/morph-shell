import QtQuick
import Quickshell
import qs.components
import qs.config

// What the dock grows into, whichever panel it is: a search field over
// a list of results. The launcher and the clipboard each hand it their
// results and a row to draw them with, and say what Enter does.
Item {
    id: root

    // Driven by the dock. Opening resets the field, so a panel always
    // opens on everything rather than on the last search.
    property bool active: false

    readonly property string query: search.text
    property string placeholder
    property string emptyText

    property var results: []
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex

    readonly property var current: results[list.currentIndex] ?? null

    // Anything else the field carries, after the text.
    property alias actions: actionRow.data

    signal dismissed
    signal accepted(var result)

    // Shift+Delete, so plain Delete still edits the search.
    signal removeRequested(var result)

    function reset(): void {
        search.text = "";
        list.currentIndex = 0;
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
            list.opacity: 1
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
                            target: list
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
                targets: [field, list]
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
    onActiveChanged: {
        if (active) {
            reset();
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

                icon: "search"
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

                // A new search starts from the top of its own results
                // rather than from wherever the last one had got to.
                onTextChanged: list.currentIndex = 0

                // The list never takes focus -- the field keeps it and
                // drives the selection -- so typing continues to work
                // while arrowing through results.
                Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, root.results.length - 1)
                Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
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

    ListView {
        id: list

        anchors.top: field.bottom
        anchors.topMargin: Appearance.spacing.small
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        clip: true
        spacing: Appearance.spacing.extraSmall

        // Closed, and sunk a little, until the open state says otherwise.
        opacity: 0

        model: ScriptModel {
            values: root.results
        }

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

        // Driven by the open state below.
        transform: Translate {
            id: listShift

            y: Appearance.spacing.large * 2
        }

        highlight: Rectangle {
            radius: Appearance.rounding.large
            color: Appearance.palette.m3surfaceContainerHigh
        }

        StyledText {
            anchors.centerIn: parent

            visible: root.results.length === 0

            text: root.emptyText
            color: Appearance.palette.m3onSurfaceVariant
        }
    }
}
