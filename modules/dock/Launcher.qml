import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// What the dock grows into: a search field over a list of everything
// installed. Lives inside the dock's own shape rather than in a window
// of its own, so opening it is the dock changing form.
Item {
    id: root

    // Driven by the dock. Opening resets the field, so the launcher
    // always opens on the whole menu rather than on the last search.
    property bool active: false

    signal dismissed

    readonly property var results: Apps.search(search.text)

    function reset(): void {
        search.text = "";
        list.currentIndex = 0;
    }

    function grabFocus(): void {
        search.forceActiveFocus();
    }

    function run(entry: DesktopEntry): void {
        if (!entry)
            return;

        Apps.launch(entry);
        root.dismissed();
    }

    onActiveChanged: {
        if (active) {
            reset();
            grabFocus();
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
        color: Appearance.palette.background

        Row {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            spacing: Appearance.spacing.small

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter

                icon: "search"
                size: Appearance.font.icon.normal
                color: Appearance.palette.subtext
            }

            TextInput {
                id: search

                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - parent.spacing - Appearance.font.icon.normal

                color: Appearance.palette.text
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.normal

                renderType: TextInput.NativeRendering
                selectByMouse: true
                selectionColor: Appearance.palette.primary
                selectedTextColor: Appearance.palette.background

                // A new search starts from the top of its own results
                // rather than from wherever the last one had got to.
                onTextChanged: list.currentIndex = 0

                // The list never takes focus -- the field keeps it and
                // drives the selection -- so typing continues to work
                // while arrowing through results.
                Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, root.results.length - 1)
                Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
                Keys.onEscapePressed: root.dismissed()
                Keys.onReturnPressed: root.run(root.results[list.currentIndex])
                Keys.onEnterPressed: root.run(root.results[list.currentIndex])

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: search.text.length === 0

                    text: qsTr("Search applications")
                    font.pixelSize: Appearance.font.normal
                    color: Appearance.palette.subtext
                }
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

        highlight: Rectangle {
            radius: Appearance.rounding.large
            color: Appearance.palette.surface

            // Lightened rather than tinted: the surface is already the
            // panel's colour, so a flat fill would be invisible.
            opacity: 0.6
        }

        delegate: Item {
            id: item

            required property int index
            required property DesktopEntry modelData

            width: list.width
            implicitHeight: Appearance.dock.resultHeight

            HoverHandler {
                id: itemHover

                cursorShape: Qt.PointingHandCursor

                // Pointing at a row selects it, so the pointer and the
                // arrows never disagree about what Enter would run.
                onHoveredChanged: if (hovered)
                    list.currentIndex = item.index
            }

            TapHandler {
                onTapped: root.run(item.modelData)
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.medium
                anchors.rightMargin: Appearance.padding.medium
                spacing: Appearance.spacing.medium

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter

                    implicitSize: Appearance.font.icon.large
                    source: Quickshell.iconPath(item.modelData.icon, "application-x-executable")
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    width: parent.width - Appearance.font.icon.large - parent.spacing

                    StyledText {
                        width: parent.width

                        text: item.modelData.name
                        font.pixelSize: Appearance.font.normal
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width

                        // Whatever the app says it is, when it says
                        // anything. The row keeps its height either way,
                        // so a list of mixed entries does not jitter.
                        visible: text.length > 0
                        text: item.modelData.genericName || item.modelData.comment || ""
                        color: Appearance.palette.subtext
                        elide: Text.ElideRight
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent

            visible: root.results.length === 0

            text: qsTr("No applications match")
            color: Appearance.palette.subtext
        }
    }
}
