//@ pragma UseQApplication
//@ pragma DropExpensiveFonts

import Quickshell
import qs.modules.bar
import qs.modules.dock
import qs.modules.notifications
import qs.modules.osd

ShellRoot {
    Bar {}
    Dock {}
    VolumeOsd {}
    NotificationPopups {}
}
