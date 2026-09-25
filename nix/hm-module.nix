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

    systemd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run morph-shell as a systemd user service.";
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "Systemd user target that starts the shell.";
      };

      environment = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["QT_QPA_PLATFORMTHEME=gtk3"];
        description = "Extra environment variables for the service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    systemd.user.services.morph-shell = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "morph-shell";
        PartOf = [cfg.systemd.target];
        After = [cfg.systemd.target];
      };

      Service = {
        Type = "exec";
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 5;
        Environment = ["QT_QPA_PLATFORM=wayland"] ++ cfg.systemd.environment;
      };

      Install.WantedBy = [cfg.systemd.target];
    };
  };
}
