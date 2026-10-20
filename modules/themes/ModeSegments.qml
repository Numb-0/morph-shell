pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Light or dark, as an M3 segmented button: an outlined pill split in
// two, the chosen half filled in secondaryContainer. The fill slides
// across to the other half rather than swapping, and the chosen glyph
// fills in as it arrives.
Rectangle {
    id: root

    required property ThemePalette tones

    property string mode: "dark"

    signal picked(string mode)

    readonly property var segments: [
        {
            mode: "light",
            icon: "light_mode",
            label: qsTr("Light")
        },
        {
            mode: "dark",
            icon: "dark_mode",
            label: qsTr("Dark")
        }
    ]

    // Read through the count, so it is looked up again once the segments
    // exist.
    readonly property Item chosen: segmentRepeater.count > 0 ? segmentRepeater.itemAt(segments.findIndex(s => s.mode === mode)) : null

    implicitWidth: segmentRow.implicitWidth
    implicitHeight: 40

    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: tones.m3outline

    // Inset from the outline, so it reads as a pill inside a pill.
    Rectangle {
        x: (root.chosen?.x ?? 0) + 3
        y: 3
        width: (root.chosen?.width ?? 0) - 6
        height: parent.height - 6
        radius: height / 2

        color: root.tones.m3secondaryContainer
        visible: root.chosen !== null

        Behavior on x {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on width {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    Row {
        id: segmentRow

        height: parent.height

        Repeater {
            id: segmentRepeater

            model: root.segments

            Item {
                id: segment

                required property var modelData

                readonly property bool on: root.mode === modelData.mode
                readonly property color tint: on ? root.tones.m3onSecondaryContainer : root.tones.m3onSurface

                width: segmentContent.implicitWidth + Appearance.padding.large * 2
                height: parent.height

                HoverHandler {
                    id: segmentHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.picked(segment.modelData.mode)
                }

                // The state layer, inset as the fill is.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3

                    radius: height / 2
                    color: root.tones.m3onSurface
                    opacity: segmentHover.hovered ? 0.08 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                Row {
                    id: segmentContent

                    anchors.centerIn: parent
                    spacing: Appearance.spacing.small

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter

                        icon: segment.modelData.icon
                        size: Appearance.font.icon.small
                        color: segment.tint
                        fill: segment.on ? 1 : 0
                        rotation: segment.on ? 0 : -45

                        Behavior on fill {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        Behavior on rotation {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: segment.modelData.label
                        color: segment.tint
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
