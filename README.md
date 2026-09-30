# morph-shell

A [Quickshell](https://quickshell.org) desktop shell for Wayland, with a
custom C++/QML plugin for the blob-morphing popups.

The blob-morphing popups were inspired by
[Caelestia Shell](https://github.com/caelestia-dots/shell).

## Compositor support

Most of the shell runs on any Wayland compositor that supports the
layer-shell protocol. A few features talk to Hyprland directly, through
Quickshell's Hyprland integration, and only work there:

| Feature | On Hyprland | Elsewhere |
| --- | --- | --- |
| Workspaces widget | Shows each monitor's workspaces, and switches them on click and scroll. | Shows only empty slots, with the active star parked on the first, and clicks and scrolls do nothing. |
| `bar toggle <panel>` over IPC | Opens the panel on the focused monitor. | Opens nothing: there is no focused monitor to pick. Panels still open from the bar itself. |

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
| UPower | Battery widget | System service: the NixOS module turns it on. |
| PipeWire | Volume widget | System service: the NixOS module turns it on. |
| MPRIS | Media widget | Nothing to install; players expose it themselves. |
| NetworkManager | Network widget | System service: enable it yourself (`networking.networkmanager.enable`). The shell talks to it over D-Bus, so `nmcli` isn't needed. |
| BlueZ | Bluetooth widget | System service: enable it yourself (`hardware.bluetooth.enable`). The shell talks to it over D-Bus, so `bluetoothctl` isn't needed. The widget hides itself when there is no adapter. Devices that pair without a PIN (headphones, most mice) pair from the panel; one that asks for a passkey needs an agent such as `blueman-applet` running. |
| power-profiles-daemon | Power profile widget | System service: the NixOS module turns it on, unless TLP is enabled (the two conflict). The shell talks to it over D-Bus, so `powerprofilesctl` isn't needed. The widget hides itself when the daemon isn't running. |
| Notification daemon | Notification centre and popups | Built in: the shell is the notification daemon itself. Don't run another one (mako, dunst, swaync) alongside it, or whichever starts first takes the D-Bus name and the other gets nothing. |

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

This installs the package and fonts, and sets `services.upower.enable`,
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
| `launcher` | `toggle` | Open the app launcher on the focused screen, or close it if it's open. Off Hyprland it opens on the first screen. |
| `launcher` | `open` | Open the app launcher on the focused screen. Off Hyprland it opens on the first screen. |
| `launcher` | `close` | Close the app launcher. |
| `notifs` | `toggleDnd` | Turn do not disturb on or off. Only critical notifications pop up while it's on; the rest still land in the centre. |
| `notifs` | `clear` | Dismiss every notification. |

For example, to open the launcher with Super+Space in Hyprland:

```
bind = SUPER, Space, exec, morph-shell ipc call launcher toggle
```

When running from a checkout (`morph-run`), point `qs` at the working
tree instead: `qs -p ~/morph-shell ipc call launcher toggle`.

## Development

```sh
nix develop
morph-build   # configure (first time) and build the plugin
morph-run     # build, then run the shell against the working tree
nix flake check   # build the package and test the NixOS module
```
