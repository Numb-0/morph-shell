//@ pragma UseQApplication
//@ pragma DropExpensiveFonts

import Quickshell
import qs.modules.bar
import qs.modules.dock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.screenshot

ShellRoot {
    Bar {}
    Dock {}
    VolumeOsd {}
    NotificationPopups {}
    Screenshot {}
}
