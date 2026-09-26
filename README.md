# morph-shell

A [Quickshell](https://quickshell.org) desktop shell for Wayland, with a
custom C++/QML plugin for the blob-morphing popups.

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

`morph-shell` also checks for UPower and PipeWire at startup and prints a
warning if either one is missing (set `MORPH_SHELL_NO_CHECK=1` to skip
the check). A missing service never stops the shell; it just leaves that
widget empty.

### 2a. NixOS module (system services)

The NixOS module is the only place that can turn on system services, so
import it even if you also use Home Manager:

```nix
{ inputs, ... }: {
  imports = [ inputs.morph-shell.nixosModules.default ];

  programs.morph-shell.enable = true;
}
```

This installs the package and fonts, and sets `services.upower.enable`
and `services.pipewire.enable` (with `pulse.enable`). Both are set with
`mkDefault`, so any value you set yourself takes priority.

| Option | Default | Description |
| --- | --- | --- |
| `programs.morph-shell.enable` | `false` | Install the shell. |
| `programs.morph-shell.package` | flake package | Package to use. |
| `programs.morph-shell.enableServices` | `true` | Turn on UPower and PipeWire. |
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
the system config and warns at build time if UPower or PipeWire is off.

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

## Development

```sh
nix develop
morph-build   # configure (first time) and build the plugin
morph-run     # build, then run the shell against the working tree
nix flake check   # build the package and test the NixOS module
```
