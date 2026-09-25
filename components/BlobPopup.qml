import QtQuick
import Morph.Blobs
import qs.config

// A panel that grows out of an anchor shape and settles below it.
//
// Follows caelestia's BlobPopup: one state change drives three separate
// animations -- width, height and content opacity -- each with its own
// timing, and the content is clipped to the panel while it grows. Theirs
// is built around an icon button that opens on click; this one grows out
// of whatever shape you point it at.
Item {
    id: root

    required property BlobGroup group

    // The shape the panel grows out of, and the y it settles below.
    required property Item anchor
    required property real anchorBottom

    property bool open: false

    // Distance between anchorBottom and the panel. Anything approaching
    // the group's smoothing leaves a visible neck; 0 fuses them.
    property real gap: 0

    property int padding: Appearance.padding.large
    property real closedWidthScale: 0.6

    // How close to the screen edge the panel may come. A panel centres
    // on its anchor, which for a widget at the end of the bar would put
    // half of it off the screen, so it is held inside this instead. It
    // is fused to the bar either way, so an anchor it is not centred
    // under still reads as the thing it grew out of.
    property real edgeMargin: Appearance.bar.margin

    // Every blob draws a smoothing radius past its own edges, which is
    // where neighbouring shapes fuse. The anchor's shape is drawn after
    // this one, so that bleed lands on top of the panel's first rows --
    // it was shaving the top off the media art. Push the content clear of
    // the neck, but only by however much the normal padding does not
    // already cover, so the panel does not end up visibly top-heavy.
    readonly property real neck: Math.max(0, group.smoothing - gap)
    readonly property real topInset: Math.max(0, neck - padding)

    default property Item content

    readonly property bool hovered: hover.hovered
    readonly property Item maskItem: grab

    // Width and height move on spatial curves of different punch; the
    // content fades on a much shorter effects curve so it has settled
    // long before the shape has.
    property real progressX: open ? 1 : 0
    property real progressY: open ? 1 : 0
    property real contentOpacity: open ? 1 : 0

    Behavior on progressX {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on progressY {
        // Same duration, but the fast spatial curve overshoots harder
        // (1.67 against 1.21) so the drop springs more than the widening.
        Anim {
            type: Anim.DefaultSpatial
            easing.bezierCurve: Appearance.anim.fastSpatial
        }
    }

    Behavior on contentOpacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    anchors.fill: parent

    // Closed, a flat sliver hidden inside the anchor; open, drawn down
    // and out into a panel.
    BlobRect {
        id: rect

        readonly property real closedY: root.anchor.y + root.anchor.height / 2
        readonly property real openY: root.anchorBottom + root.gap
        readonly property real closedWidth: root.anchor.width * root.closedWidthScale
        readonly property real openWidth: (root.content?.implicitWidth ?? 0) + root.padding * 2
        readonly property real openHeight: (root.content?.implicitHeight ?? 0) + root.padding * 2 + root.topInset

        // Centred on the anchor, then pulled back inside the margins.
        // Only ever bites once the panel has grown wider than the room
        // beside its anchor, so a panel that fits still opens straight
        // down out of it.
        x: Math.max(root.edgeMargin, Math.min(root.width - width - root.edgeMargin, root.anchor.x + (root.anchor.width - width) / 2))
        y: closedY + (openY - closedY) * root.progressY

        implicitWidth: closedWidth + (openWidth - closedWidth) * root.progressX
        implicitHeight: openHeight * root.progressY

        group: root.group
        radius: Appearance.rounding.large

        // Square where it meets the anchor.
        topLeftRadius: 0
        topRightRadius: 0

        // Squash into the direction of travel while moving.
        deformScale: 0.00001
    }

    // Spans from the anchor's bottom edge down through the panel. Without
    // it, crossing the gap drops the hover for a frame and the panel
    // snaps shut under the pointer.
    Item {
        id: grab

        readonly property real gapTop: root.anchor.y + root.anchor.height

        x: rect.x
        y: gapTop
        width: rect.width
        height: Math.max(0, rect.y + rect.height - gapTop)

        HoverHandler {
            id: hover
        }
    }

    // Reparents the injected content, clipped so it cannot spill out
    // while the shape is still growing.
    Item {
        x: rect.x
        y: rect.y + root.topInset
        width: rect.width
        height: Math.max(0, rect.height - root.topInset)

        clip: true

        opacity: root.contentOpacity
        visible: opacity > 0

        children: [root.content]
    }
}
