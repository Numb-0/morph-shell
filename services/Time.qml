pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property SystemClock clock: SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
    }

    readonly property date now: systemClock.date

    function format(fmt: string): string {
        return Qt.formatDateTime(systemClock.date, fmt);
    }
}
