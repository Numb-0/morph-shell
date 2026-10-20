import QtQuick
import Morph.Blobs
import qs.components
import qs.config
import qs.services.system

// A drop hanging from the bar while an application has the microphone,
// the camera or the screen: a glyph for each, in its own colour. It is
// part of the bar's blob, so it buds off the bar's bottom edge, and
// rides it up to hang from the top of the screen while the bar is away
// -- the one thing the bar keeps showing when hidden.
//
// With the bar out it opens up to say who, as that is when it is being
// looked at.
Item {
    id: root

    required property BlobGroup group

    // Where it hangs from: centred under `anchor`, below `anchorBottom`.
    required property Item anchor
    required property real anchorBottom

    property bool expanded: false

    // Down out of the way while a panel has the space under the bar.
    property bool suppressed: false

    readonly property bool shown: Privacy.any && !suppressed

    property real grow: shown ? 1 : 0

    Behavior on grow {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    // Close enough to the bar for the two to run together through a
    // neck, rather than read as a second, floating thing.
    readonly property real gap: 6

    readonly property real fullHeight: Appearance.font.icon.small + Appearance.padding.extraSmall * 2
    readonly property real fullWidth: Math.max(fullHeight, row.implicitWidth + Appearance.padding.medium * 2)

    // Wide as it is tall until nearly grown, so it comes out as a round
    // drop and spreads into the pill after.
    readonly property real spread: Math.max(0, (grow - 0.6) / 0.4)

    anchors.fill: parent

    BlobRect {
        id: pill

        // The spring overshoots past nothing on the way out, and a blob
        // turned inside out draws.
        implicitWidth: Math.max(0, (root.fullHeight + (root.fullWidth - root.fullHeight) * root.spread) * root.grow)
        implicitHeight: Math.max(0, root.fullHeight * root.grow)

        x: root.anchor.x + (root.anchor.width - width) / 2
        y: root.anchorBottom + root.gap

        group: root.group
        radius: height / 2

        Behavior on implicitWidth {
            enabled: root.grow === 1

            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    // Lifted out over the bar, whose blob paints a little past its own
    // edge to make the neck and would otherwise cover the top of this.
    Item {
        parent: root.parent
        z: 1

        x: pill.x
        y: pill.y
        width: pill.width
        height: pill.height

        clip: true

        opacity: root.spread
        visible: opacity > 0

        Row {
            id: row

            anchors.centerIn: parent

            spacing: Appearance.spacing.extraSmall

            Glyph {
                on: Privacy.micInUse
                icon: Audio.micMuted ? "mic_off" : "mic"
                tint: Audio.micMuted ? Appearance.palette.m3onSurfaceVariant : Appearance.palette.m3warning
            }

            Glyph {
                on: Privacy.cameraInUse
                icon: "videocam"
                tint: Appearance.palette.m3success
            }

            Glyph {
                on: Privacy.screenInUse
                icon: "screen_share"
                tint: Appearance.palette.m3error
            }

            // Who, beside the glyphs.
            Item {
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: root.expanded ? names.width : 0
                implicitHeight: names.implicitHeight

                visible: implicitWidth > 0
                clip: true

                Behavior on implicitWidth {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                StyledText {
                    id: names

                    anchors.verticalCenter: parent.verticalCenter

                    // Elided past this, so a long list does not run on
                    // under the bar's other widgets.
                    width: Math.min(implicitWidth, 260)

                    text: Privacy.everyone.join(", ")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.small
                    color: Appearance.palette.m3onSurfaceVariant
                }
            }
        }
    }

    // One per thing being taken. Popping in and out rather than
    // appearing, so a second app joining reads as something happening.
    component Glyph: MaterialSymbol {
        property bool on: false
        property color tint

        anchors.verticalCenter: parent.verticalCenter

        size: Appearance.font.icon.small
        fill: 1
        color: tint

        visible: scale > 0
        scale: on ? 1 : 0

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
