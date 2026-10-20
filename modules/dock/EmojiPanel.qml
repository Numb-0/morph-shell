import QtQuick
import qs.components
import qs.config
import qs.services.launcher

// What the dock grows into to pick an emoji, or a symbol a keyboard
// lacks: a grid of them, the recent ones first, with a search over
// their names and the words people use for them. Picking one puts it
// on the clipboard and puts the panel away, as the clipboard panel's
// entries do; pasting it is left to the app.
SearchPanel {
    id: root

    function pick(entry: var): void {
        if (!entry)
            return;

        Glyphs.pick(entry);
        root.dismissed();
    }

    columns: 9

    results: Glyphs.search(query)
    icon: "add_reaction"
    placeholder: qsTr("Search emoji and symbols")
    emptyText: Glyphs.all.length === 0 ? "" : qsTr("Nothing matches")

    onAccepted: entry => pick(entry)

    // The table is only read once something wants it.
    onActiveChanged: if (active)
        Glyphs.wanted = true

    // The selected glyph's name, so a search for "arrow" can tell its
    // two dozen apart without picking each one to find out.
    actions: StyledText {
        width: Math.min(implicitWidth, 200)

        text: root.current?.name ?? ""
        color: Colours.palette.m3onSurfaceVariant
        elide: Text.ElideRight
    }

    delegate: Item {
        id: cell

        required property int index
        required property var modelData

        width: GridView.view.cellWidth
        height: GridView.view.cellHeight

        HoverHandler {
            cursorShape: Qt.PointingHandCursor

            // Pointing at a cell selects it, as on the other panels.
            onHoveredChanged: if (hovered)
                root.currentIndex = cell.index
        }

        TapHandler {
            onTapped: root.pick(cell.modelData)
        }

        Text {
            anchors.centerIn: parent

            text: cell.modelData.glyph
            textFormat: Text.PlainText
            renderType: Text.NativeRendering

            color: Colours.palette.m3onSurface
            font.family: Appearance.font.family

            // Grows a little under the selection, as a key would. By its
            // size rather than a scale, so the glyph is drawn afresh at
            // each size rather than blown up from a smaller one, blurred.
            font.pixelSize: Math.round(Math.min(cell.width, cell.height) * (root.currentIndex === cell.index ? 0.6 : 0.5))

            Behavior on font.pixelSize {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }
}
