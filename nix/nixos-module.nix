self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.morph-shell;
in {
  options.programs.morph-shell = {
    enable = lib.mkEnableOption "the morph-shell Quickshell desktop shell";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.morph-shell;
      description = "The morph-shell package to use.";
    };

    enableServices = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Turn on the system services the widgets read from: UPower for the
        battery, PipeWire for volume and power-profiles-daemon for the
        power profile switch. Each is set with mkDefault, so an explicit
        setting elsewhere in your config wins. power-profiles-daemon is
        left off when TLP is on, since the two conflict.
      '';
    };

    systemd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run morph-shell as a systemd user service for every user. Leave
          this off if you use the Home Manager module, which has its own.
        '';
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "Systemd user target that starts the shell.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [cfg.package];
      fonts.packages = cfg.package.passthru.fonts or [];

      # The lock screen checks passwords against this service.
      security.pam.services.morph-shell = {};
    }

    (lib.mkIf cfg.enableServices {
      services.upower.enable = lib.mkDefault true;
      services.power-profiles-daemon.enable = lib.mkDefault (!config.services.tlp.enable);
      services.pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    })

    (lib.mkIf cfg.systemd.enable {
      systemd.user.services.morph-shell = {
        description = "morph-shell";
        partOf = [cfg.systemd.target];
        after = [cfg.systemd.target];
        wantedBy = [cfg.systemd.target];
        environment.QT_QPA_PLATFORM = "wayland";
        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe cfg.package;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })
  ]);
}
