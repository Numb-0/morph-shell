import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// What the dock grows into to bring something back: the clipboard's
// history, newest first, text and images alike. Picking an entry puts
// it back on the clipboard and puts the panel away; pasting it is left
// to the app, as with any copy.
SearchPanel {
    id: root

    function copy(entry: var): void {
        if (!entry)
            return;

        Clipboard.copy(entry);
        root.dismissed();
    }

    results: Clipboard.search(query)
    placeholder: qsTr("Search clipboard")
    emptyText: Clipboard.entries.length === 0 ? qsTr("Nothing copied yet") : qsTr("Nothing matches")

    onAccepted: entry => copy(entry)
    onRemoveRequested: entry => Clipboard.remove(entry)

    // The listing already follows every copy; this only catches the
    // history having been changed behind the shell's back, from a
    // terminal.
    onActiveChanged: {
        wipeButton.armed = false;
        if (active)
            Clipboard.refresh();
    }

    // Clears the whole history, so it asks first: one tap arms it and
    // turns it red, a second within a few seconds wipes.
    actions: Item {
        id: wipeButton

        property bool armed: false

        readonly property bool usable: Clipboard.entries.length > 0

        implicitWidth: 32
        implicitHeight: 32

        opacity: usable ? 1 : 0.38

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Timer {
            id: disarm

            interval: 3000
            onTriggered: wipeButton.armed = false
        }

        HoverHandler {
            id: wipeHover

            enabled: wipeButton.usable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: wipeButton.usable

            onTapped: {
                if (wipeButton.armed) {
                    wipeButton.armed = false;
                    Clipboard.wipe();
                } else {
                    wipeButton.armed = true;
                    disarm.restart();
                }
                wipeIcon.press();
            }
        }

        // The M3 state layer, or the error container once armed.
        Rectangle {
            anchors.fill: parent

            radius: height / 2
            color: wipeButton.armed ? Appearance.palette.m3errorContainer : Appearance.palette.m3onSurface
            opacity: wipeButton.armed ? 1 : wipeHover.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            Behavior on color {
                CAnim {}
            }
        }

        MaterialSymbol {
            id: wipeIcon

            anchors.centerIn: parent

            icon: "delete_sweep"
            size: Appearance.font.icon.normal
            color: wipeButton.armed ? Appearance.palette.m3onErrorContainer : Appearance.palette.m3onSurfaceVariant
            fill: wipeButton.armed ? 1 : 0
        }
    }

    delegate: Item {
        id: item

        required property int index
        required property var modelData

        readonly property bool selected: root.currentIndex === index

        width: ListView.view.width
        implicitHeight: modelData.image ? Appearance.dock.imageResultHeight : Appearance.dock.resultHeight

        HoverHandler {
            id: itemHover

            cursorShape: Qt.PointingHandCursor

            // Pointing at a row selects it, so the pointer and the
            // arrows never disagree about what Enter would copy.
            onHoveredChanged: if (hovered)
                root.currentIndex = item.index
        }

        // Not on the remove button, which sits inside the row: a tap
        // there removes the entry rather than copying it on its way out.
        TapHandler {
            onTapped: if (!removeHover.hovered)
                root.copy(item.modelData)
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.medium

            // Text gets a tonal badge where an image gets its picture,
            // so the two kinds line up down the list.
            Rectangle {
                id: badge

                anchors.verticalCenter: parent.verticalCenter

                visible: !item.modelData.image

                implicitWidth: 36
                implicitHeight: 36

                radius: Appearance.rounding.medium
                color: Appearance.palette.m3secondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent

                    icon: "notes"
                    size: Appearance.font.icon.normal
                    color: Appearance.palette.m3onSecondaryContainer
                }
            }

            // As wide as the picture's own shape gives it at the row's
            // height, within limits: a screenshot of a whole screen still
            // reads as one, and a sliver of a banner does not shrink to
            // nothing.
            ClippingRectangle {
                id: thumbnail

                anchors.verticalCenter: parent.verticalCenter

                visible: item.modelData.image

                readonly property real aspect: item.modelData.height > 0 ? item.modelData.width / item.modelData.height : 1

                implicitHeight: Appearance.dock.imageResultHeight - Appearance.padding.small * 2
                implicitWidth: Math.max(implicitHeight * 0.75, Math.min(implicitHeight * aspect, Appearance.dock.thumbnailMaxWidth))

                radius: Appearance.rounding.medium
                color: Appearance.palette.m3surfaceContainerHighest

                Image {
                    anchors.fill: parent

                    source: item.modelData.image ? `file://${item.modelData.path}` : ""
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - (item.modelData.image ? thumbnail.width : badge.width) - removeButton.width - parent.spacing * 2

                // Up to two lines of what was copied. cliphist has already
                // folded its line breaks into spaces.
                StyledText {
                    width: parent.width

                    visible: !item.modelData.image

                    text: item.modelData.text
                    font.pixelSize: Appearance.font.normal
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width

                    visible: item.modelData.image

                    text: qsTr("Image")
                    font.pixelSize: Appearance.font.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width

                    visible: item.modelData.image

                    text: item.modelData.image ? `${item.modelData.format.toUpperCase()} · ${item.modelData.width} × ${item.modelData.height} · ${item.modelData.size}` : ""
                    color: Appearance.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Shown on the row under the pointer or the arrows, and room
            // kept for it on every other, so pointing at a row never
            // reflows its text.
            Item {
                id: removeButton

                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: 32
                implicitHeight: 32

                opacity: item.selected ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                HoverHandler {
                    id: removeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Clipboard.remove(item.modelData)
                }

                Rectangle {
                    anchors.fill: parent

                    radius: height / 2
                    color: Appearance.palette.m3onSurface
                    opacity: removeHover.hovered ? 0.12 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent

                    icon: "close"
                    size: Appearance.font.icon.small
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
