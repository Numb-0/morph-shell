import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services.session

// The weather's panel, from the glyph beside the clock: how it is now,
// on a card that takes the weather's colour, and the days ahead under
// it. Everything about how it grows out of the bar lives in BlobPopup.
BlobPopup {
    id: root

    readonly property int panelWidth: 300

    // Fetches afresh on opening if the last fetch is getting old, so it
    // is never far behind after a long sleep.
    onOpenChanged: if (open)
        Weather.freshen()

    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.medium

            // The weather now, on a card that takes the weather's colour:
            // the primary tones under a clear sky, the secondary under
            // cloud, the tertiary in rain and snow. The condition's glyph
            // sits on an expressive shape picked for it, turning slowly.
            ClippingRectangle {
                id: hero

                // Clear, cloud, or anything falling from the sky. The text
                // colours are "ink" rather than onContainer: QML would read
                // that name as a handler for a "container" signal.
                readonly property int code: Weather.current?.code ?? 0
                readonly property string mood: code <= 1 ? "clear" : code <= 48 ? "cloud" : "wet"

                readonly property color container: mood === "clear" ? Appearance.palette.m3primaryContainer : mood === "cloud" ? Appearance.palette.m3secondaryContainer : Appearance.palette.m3tertiaryContainer
                readonly property color ink: mood === "clear" ? Appearance.palette.m3onPrimaryContainer : mood === "cloud" ? Appearance.palette.m3onSecondaryContainer : Appearance.palette.m3onTertiaryContainer
                readonly property color accent: mood === "clear" ? Appearance.palette.m3primary : mood === "cloud" ? Appearance.palette.m3secondary : Appearance.palette.m3tertiary
                readonly property color accentInk: mood === "clear" ? Appearance.palette.m3onPrimary : mood === "cloud" ? Appearance.palette.m3onSecondary : Appearance.palette.m3onTertiary

                visible: Weather.ready || Weather.error !== ""

                Layout.fillWidth: true
                implicitHeight: Weather.ready ? now.implicitHeight + Appearance.padding.large * 2 : 56

                radius: Appearance.rounding.extraLarge
                color: Weather.ready ? container : Appearance.palette.m3surfaceContainerHigh

                Behavior on color {
                    CAnim {}
                }

                StyledText {
                    anchors.centerIn: parent

                    visible: !Weather.ready

                    text: Weather.error
                    color: Appearance.palette.m3onSurfaceVariant
                }

                // A second, larger shape bleeding off the corner, faint,
                // so the card reads as lit from that side.
                Bloom {
                    x: parent.width - width * 0.55
                    y: -height * 0.45

                    visible: Weather.ready

                    radius: 70
                    code: hero.code
                    color: Qt.alpha(hero.accent, 0.12)
                    turning: root.open
                    reverse: true
                }

                ColumnLayout {
                    id: now

                    visible: Weather.ready

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.medium

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            // Where, as a chip.
                            Rectangle {
                                visible: Weather.place !== ""

                                implicitWidth: placeRow.implicitWidth + Appearance.padding.medium * 2
                                implicitHeight: 24

                                radius: height / 2
                                color: Qt.alpha(hero.ink, 0.1)

                                Row {
                                    id: placeRow

                                    anchors.centerIn: parent
                                    spacing: 2

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter

                                        icon: "location_on"
                                        size: Appearance.font.icon.small - 2
                                        color: hero.ink
                                        fill: 1
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter

                                        width: Math.min(implicitWidth, 120)
                                        text: Weather.place
                                        font.weight: Font.Medium
                                        color: hero.ink
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            StyledText {
                                Layout.topMargin: Appearance.spacing.small

                                text: Weather.temperature(Weather.current?.temperature ?? 0)
                                font.pixelSize: 56
                                font.weight: Font.DemiBold
                                color: hero.ink
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: -4

                                animate: true
                                text: Weather.describe(hero.code)
                                font.pixelSize: Appearance.font.normal
                                font.weight: Font.Medium
                                color: hero.ink
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Weather.days.length > 0 ? qsTr("H %1  ·  L %2").arg(Weather.temperature(Weather.days[0].max)).arg(Weather.temperature(Weather.days[0].min)) : ""
                                color: Qt.alpha(hero.ink, 0.75)
                            }
                        }

                        Item {
                            Layout.alignment: Qt.AlignTop

                            implicitWidth: 96
                            implicitHeight: 96

                            Bloom {
                                anchors.centerIn: parent

                                radius: 40
                                code: hero.code
                                color: hero.accent
                                turning: root.open
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent

                                icon: Weather.icon(hero.code, Weather.current?.isDay ?? true)
                                size: 40
                                color: hero.accentInk
                                fill: 1
                            }
                        }
                    }

                    // The rest of how it is, as three tonal pills.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Repeater {
                            model: [
                                {
                                    icon: "thermostat",
                                    text: Weather.temperature(Weather.current?.feelsLike ?? 0)
                                },
                                {
                                    icon: "humidity_percentage",
                                    text: `${Weather.current?.humidity ?? 0}%`
                                },
                                {
                                    icon: "air",
                                    text: `${Math.round(Weather.current?.wind ?? 0)} ${Weather.windUnit}`
                                }
                            ]

                            Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 32

                                radius: height / 2
                                color: Qt.alpha(hero.ink, 0.1)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.extraSmall

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter

                                        icon: modelData.icon
                                        size: Appearance.font.icon.small
                                        color: hero.ink
                                        fill: 1
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: modelData.text
                                        font.weight: Font.Medium
                                        color: hero.ink
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The days ahead, each its range drawn as a bar against the
            // whole week's, so a cold snap shows as a dip before any
            // number is read. Today stands on a tonal pill.
            Rectangle {
                id: week

                visible: Weather.ready && Weather.days.length > 0

                Layout.fillWidth: true
                implicitHeight: forecast.implicitHeight + Appearance.padding.medium * 2

                radius: Appearance.rounding.extraLarge
                color: Appearance.palette.m3surfaceContainerHigh

                readonly property real low: Math.min(...Weather.days.map(d => d.min))
                readonly property real high: Math.max(...Weather.days.map(d => d.max))

                Row {
                    id: forecast

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.medium

                    Repeater {
                        model: Weather.days

                        Item {
                            id: day

                            required property var modelData
                            required property int index

                            readonly property bool today: index === 0

                            width: forecast.width / Math.max(1, Weather.days.length)
                            implicitHeight: dayColumn.implicitHeight + Appearance.padding.small * 2

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2

                                visible: day.today
                                radius: Appearance.rounding.large
                                color: Qt.alpha(Appearance.palette.m3primary, 0.12)
                            }

                            Column {
                                id: dayColumn

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: Appearance.padding.small
                                spacing: Appearance.spacing.extraSmall

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: day.today ? qsTr("Today") : Qt.formatDate(day.modelData.date, "ddd")
                                    font.weight: Font.Medium
                                    color: day.today ? Appearance.palette.m3primary : Appearance.palette.m3onSurfaceVariant
                                }

                                MaterialSymbol {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    icon: Weather.icon(day.modelData.code, true)
                                    color: day.today ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
                                    fill: 1
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: Weather.temperature(day.modelData.max)
                                    font.weight: Font.DemiBold
                                }

                                // The track is the week's range; the fill
                                // is this day's, warm end up.
                                Rectangle {
                                    id: track

                                    readonly property real span: Math.max(1, week.high - week.low)

                                    anchors.horizontalCenter: parent.horizontalCenter

                                    implicitWidth: 6
                                    implicitHeight: 52

                                    radius: width / 2
                                    color: Qt.alpha(Appearance.palette.m3onSurface, 0.08)

                                    Rectangle {
                                        width: parent.width
                                        radius: width / 2

                                        y: parent.height * (1 - (day.modelData.max - week.low) / track.span)
                                        height: Math.max(width, parent.height * (day.modelData.max - day.modelData.min) / track.span)

                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0
                                                color: Appearance.palette.m3primary
                                            }
                                            GradientStop {
                                                position: 1
                                                color: Appearance.palette.m3tertiary
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: Weather.temperature(day.modelData.min)
                                    color: Appearance.palette.m3onSurfaceVariant
                                }

                                // Kept in the layout on dry days too, so
                                // the columns stay level.
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    opacity: day.modelData.rain >= 20 ? 1 : 0

                                    implicitWidth: rainRow.implicitWidth + Appearance.padding.small * 2
                                    implicitHeight: 20

                                    radius: height / 2
                                    color: Appearance.palette.m3tertiaryContainer

                                    Row {
                                        id: rainRow

                                        anchors.centerIn: parent
                                        spacing: 1

                                        MaterialSymbol {
                                            anchors.verticalCenter: parent.verticalCenter

                                            icon: "water_drop"
                                            size: 12
                                            color: Appearance.palette.m3onTertiaryContainer
                                            fill: 1
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter

                                            text: `${day.modelData.rain}`
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Appearance.palette.m3onTertiaryContainer
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
