# morph-shell

A [Quickshell](https://quickshell.org) desktop shell for Wayland, with a
custom C++/QML plugin for the blob-morphing popups.

The blob-morphing popups were inspired by
[Caelestia Shell](https://github.com/caelestia-dots/shell).

## Compositor support

morph-shell is made for Hyprland: for full functionality, run it there.

Most of the shell runs on any Wayland compositor that supports the
layer-shell protocol (so not GNOME). A few features talk to Hyprland
directly, through Quickshell's Hyprland integration, and only work there:

| Feature | On Hyprland | Elsewhere |
| --- | --- | --- |
| Workspaces widget | Shows each monitor's workspaces, and switches them on click and scroll. | Shows only empty slots, with the active one parked on the first, and clicks and scrolls do nothing. |
| `bar toggle <panel>` over IPC | Opens the panel on the focused monitor. | Opens nothing: there is no focused monitor to pick. Panels still open from the bar itself. |
| Closing bar panels on an outside click | A click anywhere outside them, on any monitor, closes them, through a Hyprland focus grab. | Only a click elsewhere on the same screen closes them. |
| Closing the launcher or the clipboard on an outside click | A click anywhere outside the dock, on any monitor, closes it. | Clicks outside don't close it; use Escape or the IPC `close`. |
| `launcher`/`clipboard` `toggle`/`open` over IPC | Opens the panel on the focused monitor. | Opens it on the first screen. |
| Screenshot region picker | Snaps to the window under the pointer, and outlines it from the first frame. | Only drags or the whole screen, and the outline waits for the pointer to move. |
| Workspace overview | Shows each workspace with its windows live, and switches, focuses, closes and moves them. | Opens on an empty grid, and nothing in it does anything. |
| Colour picker | The lens is under the pointer from the first frame. | The lens waits for the pointer to move. |

Switching workspaces uses Hyprland's Lua dispatchers, so it needs a
Hyprland with the Lua config (tested on 0.56).

## Installing with Nix

The flake provides a package (`packages.<system>.morph-shell`) and a
Home Manager module (`homeManagerModules.default`).

### 1. Add the flake input

In your system/home flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    morph-shell = {
      url = "github:Numb-0/morph-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Make sure `inputs` gets passed to your modules, e.g. with
`specialArgs = { inherit inputs; };` (NixOS) or
`extraSpecialArgs = { inherit inputs; };` (Home Manager).

### What the flake takes care of

| Dependency | Used for | How it's handled |
| --- | --- | --- |
| JetBrains Mono, Material Symbols Rounded | Text and icons | Bundled with the package; installing them yourself isn't needed. |
| `brightnessctl` | Brightness widget | Put on the wrapper's `PATH`. |
| `grim`, `wl-clipboard`, `libnotify`, `satty`, `coreutils` | Screenshots; `wl-clipboard` and `libnotify` also for the colour picker | Put on the wrapper's `PATH`. |
| `dbus-send` | Power profile widget's startup check | Put on the wrapper's `PATH`. |
| `cliphist`, `wl-clipboard` | Clipboard history | Put on the wrapper's `PATH`. The shell runs the `wl-paste --watch cliphist store` watchers itself, for text and images; ones already started from your compositor config do no harm, since cliphist doesn't store an entry twice. Without cliphist the history is off, and `:cliphist` isn't offered. |
| `hyprctl` | Screenshot and colour pickers' pointer position, and the workspace and scale of each screen | Comes with Hyprland; not put on the `PATH`. Only used on Hyprland. |
| `loginctl`, `systemctl` | Session panel's Lock, Restart and Shut down | Part of systemd; not put on the `PATH`. |
| [chromix](https://github.com/Numb-0/chromix) | Theme panel, colours and wallpaper | Optional, install it yourself. The theme panel only shows when it is installed (see [Colours](#colours)). |
| StatusNotifierItem | System tray | Nothing to install: the shell is the tray host, and apps that support it show up there. Apps that only speak the old XEmbed tray don't. |
| UPower | Battery widget | System service: the NixOS module turns it on. |
| PipeWire | Volume widget | System service: the NixOS module turns it on. |
| MPRIS | Media widget | Nothing to install; players expose it themselves. |
| NetworkManager | Network widget | System service: enable it yourself (`networking.networkmanager.enable`). The shell talks to it over D-Bus, so `nmcli` isn't needed. |
| BlueZ | Bluetooth widget | System service: enable it yourself (`hardware.bluetooth.enable`). The shell talks to it over D-Bus, so `bluetoothctl` isn't needed. The widget hides itself when there is no adapter. Devices that pair without a PIN (headphones, most mice) pair from the panel; one that asks for a passkey needs an agent such as `blueman-applet` running. |
| power-profiles-daemon | Power profile widget | System service: the NixOS module turns it on, unless TLP is enabled (the two conflict). The shell talks to it over D-Bus, so `powerprofilesctl` isn't needed. The widget hides itself when the daemon isn't running. |
| Notification daemon | Notification centre and popups | Built in: the shell is the notification daemon itself. Don't run another one (mako, dunst, swaync) alongside it, or whichever starts first takes the D-Bus name and the other gets nothing. |
| polkit agent | Password prompts for `pkexec` and other privileged actions | Built in: the shell is the session's polkit agent. polkitd itself is a system service (`security.polkit.enable`, on by default on NixOS). Don't run another agent (hyprpolkitagent, polkit-gnome) alongside it: only one can register per session, and whichever starts first wins. |
| Screen locker | Locking the session | Built in: the shell is the locker, through the session-lock protocol, so hyprlock isn't needed. The NixOS module adds the `morph-shell` PAM service it checks passwords against; without it, the lock falls back to `login`'s. An idle daemon still decides when to lock (see [Lock screen](#lock-screen)). |

`morph-shell` also checks for UPower, PipeWire, NetworkManager and
power-profiles-daemon at startup and prints a warning if any of them is
missing (set `MORPH_SHELL_NO_CHECK=1` to skip the check). A missing
service never stops the shell; it just leaves that widget empty.
Subcommands that only talk to a running shell, such as `morph-shell
ipc`, skip the check.

### 2a. NixOS module (system services)

The NixOS module is the only place that can turn on system services, so
import it even if you also use Home Manager:

```nix
{ inputs, ... }: {
  imports = [ inputs.morph-shell.nixosModules.default ];

  programs.morph-shell.enable = true;
}
```

This installs the package and fonts, adds the `morph-shell` PAM service
the lock screen uses, and sets `services.upower.enable`,
`services.pipewire.enable` (with `pulse.enable`) and
`services.power-profiles-daemon.enable` (only when TLP is off). All are
set with `mkDefault`, so any value you set yourself takes priority.

| Option | Default | Description |
| --- | --- | --- |
| `programs.morph-shell.enable` | `false` | Install the shell. |
| `programs.morph-shell.package` | flake package | Package to use. |
| `programs.morph-shell.enableServices` | `true` | Turn on UPower, PipeWire and power-profiles-daemon. |
| `programs.morph-shell.systemd.enable` | `false` | Start the shell as a systemd user service for every user. |
| `programs.morph-shell.systemd.target` | `"graphical-session.target"` | Target that starts the service. |

If you don't use Home Manager, set `systemd.enable = true`, or start the
shell from your compositor instead (e.g. Hyprland's `exec-once = morph-shell`).

### 2b. Home Manager module (autostart)

```nix
{ inputs, ... }: {
  imports = [ inputs.morph-shell.homeManagerModules.default ];

  programs.morph-shell.enable = true;
}
```

If Home Manager runs as a NixOS module, put this inside
`home-manager.users.<you> = { ... };` and add
`home-manager.extraSpecialArgs = { inherit inputs; };`. Home Manager
can't turn on system services, but when it runs inside NixOS it reads
the system config and warns at build time if UPower, PipeWire or
power-profiles-daemon is off.

This installs `morph-shell` and a systemd user service that starts with
`graphical-session.target`:

| Option | Default | Description |
| --- | --- | --- |
| `programs.morph-shell.enable` | `false` | Install the shell. |
| `programs.morph-shell.package` | flake package | Package to use. |
| `programs.morph-shell.systemd.enable` | `true` | Run it as a systemd user service. |
| `programs.morph-shell.systemd.target` | `"graphical-session.target"` | Target that starts the service. |
| `programs.morph-shell.systemd.environment` | `[]` | Extra env vars, e.g. `["QT_QPA_PLATFORMTHEME=gtk3"]`. |

Your compositor has to activate `graphical-session.target` (Hyprland via
UWSM or `wayland.windowManager.hyprland.systemd.enable`, niri, Sway with
`wayland.windowManager.sway.systemd.enable`, …). If it doesn't, set
`systemd.enable = false` and start the shell from your compositor.

Manage the service with:

```sh
systemctl --user restart morph-shell
journalctl --user -u morph-shell -f
```

### Extra runtime tools

Add more programs to the shell's `PATH` with an override:

```nix
programs.morph-shell.package =
  inputs.morph-shell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    extraRuntimeDeps = [ pkgs.some-tool ];
  };
```

### 3. Rebuild

```sh
sudo nixos-rebuild switch --flake .#<host>
# or, standalone Home Manager:
home-manager switch --flake .#<user>
```

To pull the latest version later: `nix flake update morph-shell`.

### Try it without installing

```sh
nix run github:Numb-0/morph-shell
```

## Colours

The shell reads its Material 3 palette from
`$XDG_STATE_HOME/morph-shell/colors.json` (by default
`~/.local/state/morph-shell/colors.json`). The file is a flat JSON object
of role names to hex colours, in camelCase or snake_case, the way
matugen writes them:

```json
{ "primary": "#a8c8ff", "onPrimary": "#07305f", "surface": "#111318", ... }
```

Keys the shell doesn't know are ignored, and a role the file leaves out
falls back to the built-in default, as does every role when the file is
missing. The palette lives in `config/Appearance.qml`; besides the
standard M3 roles it reads `success`, `warning` and their `on…`/`…Container`
variants.

The shell watches the file and fades to the new colours when it is
edited or replaced. A switcher that repoints a symlink further up the
chain, which the watch can't see, should call
`morph-shell ipc call palette reload` afterwards.

[chromix](https://github.com/Numb-0/chromix) writes this file: its
`morph-shell` target renders the matugen template for each theme, links
the result here and triggers the reload. It also drives the theme panel
in the bar, which only shows when chromix is installed.

## Wallpaper

The shell draws the wallpaper itself, on the background layer of every
screen, so no wallpaper daemon is needed. It reads the image from
`$XDG_STATE_HOME/morph-shell/wallpaper.json` (by default
`~/.local/state/morph-shell/wallpaper.json`), next to the colours:

```json
{ "image": "/path/to/wallpaper.png" }
```

chromix's own `chromix.json`, with the image under `source.image`, is
read as is. When the image changes, the new one loads in the background
and crossfades over the old one. With no file, or no image in it, the
screen is plain `surface`. The file is watched like `colors.json`, and
`morph-shell ipc call palette reload` re-reads both.

chromix's `morph-shell` target links each theme's `chromix.json` here,
so switching theme also switches the wallpaper.

## IPC

The running shell can be controlled from the command line through
Quickshell's IPC, which is handy for compositor keybinds. The installed
`morph-shell` wrapper already points at the shell's config, so pass the
`ipc` subcommand straight to it:

```sh
morph-shell ipc call <target> <function>
morph-shell ipc show   # list every target and function the running shell exposes
```

| Target | Function | Description |
| --- | --- | --- |
| `bar` | `toggle <panel>` | Open or close a bar panel on the focused screen (Hyprland only): `clock`, `media`, `volume`, `brightness`, `battery`, `network`, `bluetooth`, `notifications`, `session` or `theme`. |
| `bar` | `togglePinned` | Pin or unpin the bar (see [Bar and dock](#bar-and-dock)). |
| `dock` | `togglePinned` | Pin or unpin the dock (see [Bar and dock](#bar-and-dock)). |
| `launcher` | `toggle` | Open the app launcher on the focused screen, or close it if it's open. Off Hyprland it opens on the first screen. |
| `launcher` | `open` | Open the app launcher on the focused screen. Off Hyprland it opens on the first screen. |
| `launcher` | `close` | Close the app launcher. |
| `clipboard` | `toggle` | Open the clipboard history on the focused screen, or close it if it's open. Off Hyprland it opens on the first screen. |
| `clipboard` | `open` | Open the clipboard history on the focused screen. Off Hyprland it opens on the first screen. |
| `clipboard` | `close` | Close the clipboard history. |
| `lock` | `lock` | Lock the session (see [Lock screen](#lock-screen)). Does nothing if it's already locked. |
| `lock` | `isLocked` | Print whether the session is locked. |
| `notifs` | `toggleDnd` | Turn do not disturb on or off. Only critical notifications pop up while it's on; the rest still land in the centre. |
| `notifs` | `clear` | Dismiss every notification. |
| `palette` | `reload` | Re-read `colors.json` and `wallpaper.json` (see [Colours](#colours) and [Wallpaper](#wallpaper)). |
| `screenshot` | `region` | Pick a region to screenshot (see [Screenshots](#screenshots)). |
| `screenshot` | `cancel` | Close the region picker without taking anything. |
| `overview` | `toggle` | Open or close the workspace overview (see [Workspace overview](#workspace-overview)). |
| `overview` | `open` | Open the workspace overview. |
| `overview` | `close` | Close the workspace overview. |
| `colorpicker` | `pick` | Pick a colour from the screen (see [Colour picker](#colour-picker)). |
| `colorpicker` | `cancel` | Close the colour picker without taking anything. |

For example, to open the launcher with Super+Space and the clipboard
history with Super+V in Hyprland:

```
bind = SUPER, Space, exec, morph-shell ipc call launcher toggle
bind = SUPER, V, exec, morph-shell ipc call clipboard toggle
```

When running from a checkout (`morph-run`), point `qs` at the working
tree instead: `qs -p ~/morph-shell ipc call launcher toggle`.

## Bar and dock

The bar floats at the top of the screen and the dock at the bottom.
Both hide until the pointer reaches their edge, unless pinned: the pin
button on each, or `bar togglePinned` / `dock togglePinned` over IPC,
holds it open and keeps room for it so windows don't go under it. The
pinned state is kept in Quickshell's state directory for the shell and
survives restarts.

The dock shows the pinned apps, a dot under the ones running, and
bounces an icon while its app launches. Opening the launcher grows the
dock into a fuzzy search over every desktop entry.

A search in the launcher that starts with `:` runs one of the shell's
own commands instead, and `:` alone lists them all:

| Command | Does |
| --- | --- |
| `:cliphist` | Turns the launcher into the clipboard history (see below). Typing the name is enough; it opens without Enter. |
| `:screenshot` | Picks a region to screenshot (see [Screenshots](#screenshots)). |
| `:colorpicker` | Picks a colour from the screen (see [Colour picker](#colour-picker)). |
| `:lock` | Locks the session. |
| `:session` | Opens the bar's session panel: log out, restart or shut down. |
| `:dnd` | Turns do not disturb on or off. |
| `:clear` | Dismisses every notification. |

The clipboard history, reached through `:cliphist` or the `clipboard`
IPC target, holds text and images, newest first, with a search over
them. Enter or a click copies an entry back to the clipboard, ready to
paste. Shift+Delete or the cross on a row removes it, and the button in
the search field clears the whole history after a second tap.

The workspaces widget comes in four styles:

| Style | Look |
| --- | --- |
| `drop` | A drop that leaps from slot to slot and splashes down. |
| `fluid` | A pool of liquid poured from slot to slot. |
| `constellation` | Workspaces in use as linked stars, the active one a comet. |
| `shapes` (default) | The active workspace a Material 3 Expressive shape that sheds its lobes, rolls over and blooms into the next workspace's. |

The bar also carries a system tray, whose menus open as panels like the
rest.

## Configuration

There is no config file yet: the knobs live in `config/Appearance.qml`,
so changing them means editing a checkout (or overriding the package's
source). The ones you're most likely to want:

| Property | Default | Description |
| --- | --- | --- |
| `bar.workspaces.style` | `"shapes"` | Workspaces style: `drop`, `fluid`, `constellation` or `shapes`. |
| `bar.workspaces.shown` | `5` | Slots always drawn; the row grows past it to reach the highest workspace in use. |
| `dock.pinned` | `["firefox", "kitty", "code", "spotify", "org.gnome.Nautilus", "discord-canary"]` | Apps in the dock, by desktop entry id (the `.desktop` file's name without the suffix). Near misses are looked up heuristically, and ids nothing answers to are skipped. |
| `dock.maxResults` | `7` | Rows the launcher shows. |
| `media.launchers` | `["spotify"]` | Players the media panel lists to start when nothing is playing, by desktop entry id. Ones that aren't installed are left out. |
| `osd.timeout` | `1500` | Milliseconds the volume OSD stays up after the level last moved. |
| `notifs.maxPopups` | `4` | Popups shown at once; older ones wait in the centre. |
| `font.family` | `"JetBrains Mono"` | Text font. |

## Lock screen

`morph-shell ipc call lock lock` locks every screen over the wallpaper,
with the time in the top left and a password field under the middle.
Type and press Enter; Escape clears what you typed. A wrong password
shakes the field, the right one turns it into a tick and the lock
fades away.

The shell only draws the lock. Deciding when to lock is left to an idle
daemon, so point its lock command at the shell. With hypridle:

```
general {
    lock_cmd = morph-shell ipc call lock lock
}
```

`loginctl lock-session`, which the session panel's Lock button sends,
then reaches the shell through hypridle too.

The compositor keeps the session locked if the shell dies while it's
up, so a crash never unlocks the desktop. On Hyprland, set
`misc:allow_session_lock_restore = true` so the restarted shell can be
locked again over it with the command above.

## Screenshots

`morph-shell ipc call screenshot region` dims every screen and outlines
what a click would take: the window under the pointer, or the whole
screen over bare desktop. Drag to take a rectangle instead. Escape or a
right click cancels.

The shell only picks the region, the way `slurp` would; `grim` takes the
picture. It goes straight to the clipboard and to
`~/Pictures/Screenshots/<date>_<time>.png` (under `$XDG_PICTURES_DIR`
when that is set), and a notification says so for 8 seconds. Clicking
it, or its Edit button, opens the file in `satty`. The notification
stays in the centre after the popup goes, and Edit still works from
there.

The picker snaps to windows through Hyprland's IPC. Elsewhere it still
works, but only by dragging or taking the whole screen.

```
bind = , Print, exec, morph-shell ipc call screenshot region
```

## Workspace overview

`morph-shell ipc call overview toggle` puts a grid of the workspaces in
use over every screen, with each window drawn live where it sits. The
one on screen is always there, empty or not, and a last cell with a
plus stands for the first free workspace.

- Click a workspace to go there, or a window to focus it.
- Middle-click a window to close it.
- Drag a window onto another workspace to move it there, without
  following it. Dropped on the plus, it gets a workspace of its own.
- Arrow keys (or `hjkl`) move around the grid and Enter goes to the
  workspace picked; `1` to `9` and `0` go straight to that workspace,
  shown or not.
- Escape, a right click, or a click off the grid closes it.

Behind the grid the screen blurs as the overview opens and comes back
into focus as it closes; going to another workspace fades the blurred
screen into the new one instead. The shell blurs a still of the screen
itself, so no blur rule is needed in Hyprland, and one would only pop in
underneath.

The grid's shape and how much of the screen it takes are set under
`overview` in `config/Appearance.qml`. It needs Hyprland: elsewhere it
opens empty.

```
bind = SUPER, Tab, exec, morph-shell ipc call overview toggle
```

## Colour picker

`morph-shell ipc call colorpicker pick` freezes every screen and puts a
lens beside the pointer that magnifies the pixels under it, with the
colour of the middle one written below. A click copies that colour as
hex (`#RRGGBB`) and a notification shows it along with its `rgb()`.
Escape or a right click cancels. It stands in for `hyprpicker`.

The colour is read from the screen's own pixels, at its native
resolution, so it is exact on fractionally scaled screens too.

```
bind = SUPER SHIFT, C, exec, morph-shell ipc call colorpicker pick
```

## Development

```sh
nix develop
morph-build   # configure (first time) and build the plugin
morph-run     # build, then run the shell against the working tree
nix flake check   # build the package and test the NixOS module
```
