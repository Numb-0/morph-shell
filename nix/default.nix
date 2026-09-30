{
  lib,
  stdenv,
  cmake,
  ninja,
  makeWrapper,
  writeText,
  writeShellScript,
  qt6,
  spirv-tools,
  quickshell,
  dbus,
  brightnessctl,
  coreutils,
  grim,
  wl-clipboard,
  libnotify,
  satty,
  jetbrains-mono,
  material-symbols,
  extraRuntimeDeps ? [],
  fonts ? [jetbrains-mono material-symbols],
}: let
  # dbus-send: the power profile widget pings power-profiles-daemon once
  # at startup to decide whether to show itself. grim, wl-copy,
  # notify-send and satty: the screenshot pipeline, which also wants
  # coreutils even when the shell runs as a service with a bare PATH.
  runtimeDeps = [brightnessctl dbus coreutils grim wl-clipboard libnotify satty] ++ extraRuntimeDeps;

  # Layer the bundled fonts on top of the system fontconfig, so the shell
  # finds them whether or not they are installed, and every other font
  # the user has stays visible.
  fontsConf = writeText "morph-shell-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      ${lib.concatMapStrings (f: "<dir>${f}/share/fonts</dir>\n  ") fonts}
    </fontconfig>
  '';

  # System services the shell talks to but cannot bring along itself.
  # Warns on stderr and never blocks startup: a missing service only
  # leaves its widget empty.
  preflight = writeShellScript "morph-shell-preflight" ''
    [ -n "''${MORPH_SHELL_NO_CHECK:-}" ] && exit 0

    warn() { echo "morph-shell: warning: $*" >&2; }

    # Pinging the name also triggers D-Bus activation, so this passes
    # when UPower is installed but not started yet.
    if ! ${dbus}/bin/dbus-send --system --print-reply=literal \
        --dest=org.freedesktop.UPower /org/freedesktop/UPower \
        org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
      warn "UPower is not available; the battery widget will be empty." \
        "On NixOS set services.upower.enable = true."
    fi

    if [ ! -S "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire-0" ]; then
      warn "PipeWire is not running; the volume widget will be empty." \
        "On NixOS set services.pipewire.enable = true."
    fi

    if ! ${dbus}/bin/dbus-send --system --print-reply=literal \
        --dest=org.freedesktop.NetworkManager /org/freedesktop/NetworkManager \
        org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
      warn "NetworkManager is not available; the network widget will be empty." \
        "On NixOS set networking.networkmanager.enable = true."
    fi

    if ! ${dbus}/bin/dbus-send --system --print-reply=literal \
        --dest=org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
        org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
      warn "power-profiles-daemon is not available; the power profile widget will be hidden." \
        "On NixOS set services.power-profiles-daemon.enable = true."
    fi

    exit 0
  '';
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "morph-shell";
    version = "0.1.0";

    src = builtins.path {
      path = ../.;
      name = "morph-shell-src";
    };

    nativeBuildInputs = [
      cmake
      ninja
      makeWrapper
      qt6.wrapQtAppsHook
      qt6.qtshadertools
      spirv-tools
    ];

    buildInputs = [
      qt6.qtbase
      qt6.qtdeclarative
      quickshell
    ];

    # We do not ship a Qt app of our own — we wrap quickshell's binary below.
    # (makeShellWrapper, not makeWrapper: the Qt hook swaps in the binary
    # wrapper, which has no --run for the preflight check.)
    dontWrapQtApps = true;

    # The preflight check is for starting the shell. Subcommands that only
    # talk to a running instance (e.g. `morph-shell ipc call ...` from a
    # keybind) skip it, so they don't repeat its warnings on every call.
    postInstall = ''
      makeShellWrapper ${quickshell}/bin/quickshell $out/bin/morph-shell \
        --run 'case "''${1:-}" in ipc|msg|log|list|kill) ;; *) ${preflight} ;; esac' \
        --prefix QML2_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
        --set-default FONTCONFIG_FILE "${fontsConf}" \
        --add-flags "-p $out/share/morph-shell"
    '';

    passthru = {inherit fonts runtimeDeps;};

    meta = {
      description = "A Quickshell desktop shell";
      platforms = lib.platforms.linux;
      mainProgram = "morph-shell";
    };
  })
