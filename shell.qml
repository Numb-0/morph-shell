//@ pragma UseQApplication
//@ pragma DropExpensiveFonts

import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.dock
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.screenshot

ShellRoot {
    Background {}
    Bar {}
    Dock {}
    VolumeOsd {}
    NotificationPopups {}
    Screenshot {}
    Polkit {}
    Lock {}
}
