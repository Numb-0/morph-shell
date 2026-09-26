self: {
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  cfg = config.programs.morph-shell;

  # Only set when Home Manager runs as a NixOS module. System services
  # are out of Home Manager's reach, so the best it can do is point out
  # the ones the shell needs.
  osEnabled = path: osConfig == null || lib.attrByPath path false osConfig;
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

    warnings =
      lib.optional (!osEnabled ["services" "upower" "enable"])
      "programs.morph-shell: services.upower.enable is off in your NixOS config; the battery widget will be empty."
      ++ lib.optional (!osEnabled ["services" "pipewire" "enable"])
      "programs.morph-shell: services.pipewire.enable is off in your NixOS config; the volume widget will be empty.";

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
