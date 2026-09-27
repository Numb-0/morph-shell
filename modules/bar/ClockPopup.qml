import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// The clock's panel: the date and time, and a month calendar under them.
// Everything about how it grows out of the bar lives in BlobPopup.
//
// The calendar is Qt's own MonthGrid and DayOfWeekRow, which work out
// the days and follow the locale's first day of the week; only the
// delegates are ours, drawn as M3's date picker draws them.
BlobPopup {
    id: root

    readonly property int panelWidth: 300

    // The month on show. Starts on today's and goes back there whenever
    // the panel closes, so it never opens on a month paged to last time.
    property int shownMonth: Time.now.getMonth()
    property int shownYear: Time.now.getFullYear()

    function page(delta: int): void {
        const d = new Date(shownYear, shownMonth + delta, 1);
        shownMonth = d.getMonth();
        shownYear = d.getFullYear();
    }

    function resetMonth(): void {
        shownMonth = Time.now.getMonth();
        shownYear = Time.now.getFullYear();
    }

    readonly property bool onToday: shownMonth === Time.now.getMonth() && shownYear === Time.now.getFullYear()

    onOpenChanged: if (!open)
        resetMonth()

    // A round, borderless icon button with an M3 state layer.
    component IconButton: Item {
        id: btn

        required property string icon
        property color color: Appearance.palette.m3onSurface

        signal activated

        implicitWidth: 32
        implicitHeight: 32

        HoverHandler {
            id: btnHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: btn.activated()
        }

        Rectangle {
            anchors.fill: parent

            radius: width / 2
            color: btn.color
            opacity: btnHover.hovered ? 0.12 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent

            icon: btn.icon
            size: Appearance.font.icon.small
            color: btn.color
        }
    }

    Item {
        anchors.centerIn: parent

        implicitWidth: root.panelWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.medium

            // The day and date on the left, the time set large on the
            // right, as the top of an M3 date picker carries its headline.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.padding.small
                Layout.rightMargin: Appearance.padding.small
                spacing: Appearance.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Time.format("dddd")
                        font.pixelSize: Appearance.font.large
                        color: Appearance.palette.m3primary
                    }

                    StyledText {
                        text: Time.format("d MMMM yyyy")
                        color: Appearance.palette.m3onSurfaceVariant
                    }
                }

                // Deliberately not animated: this changes every second,
                // and the fade would read as a flicker.
                StyledText {
                    text: Time.format("hh:mm")
                    font.pixelSize: 32
                    font.weight: Font.Medium
                }
            }

            // The calendar on its own tonal card.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: calendar.implicitHeight + Appearance.padding.medium * 2

                radius: Appearance.rounding.extraLarge
                color: Appearance.palette.m3surface

                ColumnLayout {
                    id: calendar

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.medium
                    spacing: Appearance.spacing.small

                    // Month and year, the arrows to page, and a way back
                    // to today that only shows once paged away from it.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Appearance.padding.small

                            animate: true
                            // Formatted as Time formats the header above,
                            // so the two agree on a language.
                            text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
                            font.pixelSize: Appearance.font.normal
                            font.weight: Font.Medium
                        }

                        IconButton {
                            icon: "today"
                            color: Appearance.palette.m3primary

                            opacity: root.onToday ? 0 : 1
                            visible: opacity > 0
                            onActivated: root.resetMonth()

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }
                        }

                        IconButton {
                            icon: "chevron_left"
                            onActivated: root.page(-1)
                        }

                        IconButton {
                            icon: "chevron_right"
                            onActivated: root.page(1)
                        }
                    }

                    DayOfWeekRow {
                        Layout.fillWidth: true

                        locale: grid.locale
                        spacing: 0
                        padding: 0

                        // Named the same way as the month, rather than
                        // by the locale, which only picks the first day.
                        // 1 January 2024 was a Monday, so day n of the
                        // week (Monday = 1) falls on the nth.
                        delegate: StyledText {
                            required property int day

                            text: Qt.formatDate(new Date(2024, 0, day), "ddd").charAt(0)
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.palette.m3outline
                            font.weight: Font.Medium
                        }
                    }

                    MonthGrid {
                        id: grid

                        Layout.fillWidth: true

                        month: root.shownMonth
                        year: root.shownYear
                        locale: Qt.locale()
                        spacing: 2
                        padding: 0

                        // Scrolling pages the months, one notch at a time.
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => root.page(event.angleDelta.y > 0 ? -1 : 1)
                        }

                        delegate: Item {
                            id: cell

                            required property var model

                            // Checked against the clock rather than the
                            // model's own flag, which is only worked out
                            // when the month is built and would go stale
                            // across midnight.
                            readonly property bool isToday: model.day === Time.now.getDate() && model.month === Time.now.getMonth() && model.year === Time.now.getFullYear()
                            readonly property bool inMonth: model.month === grid.month

                            implicitWidth: 36
                            implicitHeight: 34

                            HoverHandler {
                                id: cellHover
                            }

                            // Today is a filled circle, as M3 marks the
                            // current date; the rest only light up under
                            // the pointer.
                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 32

                                radius: width / 2
                                color: cell.isToday ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
                                opacity: cell.isToday ? 1 : cellHover.hovered && cell.inMonth ? 0.1 : 0
                                scale: cell.isToday || cellHover.hovered ? 1 : 0.6

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.FastEffects
                                    }
                                }

                                Behavior on scale {
                                    Anim {
                                        type: Anim.FastSpatial
                                    }
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent

                                text: cell.model.day
                                font.weight: cell.isToday ? Font.Bold : Font.Normal
                                color: cell.isToday ? Appearance.palette.m3onPrimary : cell.inMonth ? Appearance.palette.m3onSurface : Qt.alpha(Appearance.palette.m3outline, 0.6)
                            }
                        }
                    }
                }
            }
        }
    }
}
