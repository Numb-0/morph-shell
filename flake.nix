{
  description = "morph-shell — a Quickshell desktop shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: rec {
      morph-shell = pkgs.callPackage ./nix {};
      default = morph-shell;
    });

    devShells = forAllSystems (pkgs: let
      # The tools the installed wrapper puts on the shell's PATH, so a
      # run from the working tree finds the same ones -- cliphist,
      # grim, brightnessctl -- whether or not they are installed.
      runtimeDeps = self.packages.${pkgs.stdenv.hostPlatform.system}.morph-shell.passthru.runtimeDeps;

      # Configure on first run, then build. Extra arguments are passed
      # through to cmake --build (e.g. `morph-build --target morphblobs`).
      morph-build = pkgs.writeShellScriptBin "morph-build" ''
        set -euo pipefail

        root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
        cd "$root"

        if [ ! -f build/build.ninja ]; then
          echo ">> configuring"
          ${pkgs.cmake}/bin/cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
        fi

        ${pkgs.cmake}/bin/cmake --build build "$@"
      '';

      # Build, then launch the shell against the working tree with the
      # freshly built plugin on the QML import path.
      morph-run = pkgs.writeShellScriptBin "morph-run" ''
        set -euo pipefail

        root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
        cd "$root"

        ${morph-build}/bin/morph-build

        # Avoid stacking bars if one is already up.
        ${pkgs.quickshell}/bin/qs kill -p "$root" 2>/dev/null || true

        export QML2_IMPORT_PATH="$root/build/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
        export QML_IMPORT_PATH="$root/build/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
        export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

        exec ${pkgs.quickshell}/bin/qs -p "$root" "$@"
      '';
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          cmake
          ninja
          pkg-config
          qt6.qtbase
          qt6.qtdeclarative
          qt6.qtshadertools
          spirv-tools
          quickshell
          morph-build
          morph-run
        ];

        shellHook = ''
          echo "morph-shell dev shell"
          echo "  morph-build   configure (first time) and build the plugin"
          echo "  morph-run     build, then run the shell against this tree"
        '';
      };
    });

    nixosModules = {
      morph-shell = import ./nix/nixos-module.nix self;
      default = self.nixosModules.morph-shell;
    };

    # `nix flake check`: build the package and evaluate the NixOS module
    # with everything it switches on.
    checks = forAllSystems (pkgs: {
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.morph-shell;

      nixos-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            self.nixosModules.default
            {
              programs.morph-shell = {
                enable = true;
                systemd.enable = true;
              };
              boot.loader.grub.enable = false;
              fileSystems."/".device = "nodev";
              system.stateVersion = "25.11";
            }
          ];
        };
        cfg = eval.config;
      in
        assert cfg.services.upower.enable;
        assert cfg.services.pipewire.enable;
        assert builtins.elem pkgs.material-symbols cfg.fonts.packages;
        assert cfg.security.pam.services ? morph-shell;
          pkgs.writeText "morph-shell-nixos-module-check"
          cfg.systemd.user.services.morph-shell.serviceConfig.ExecStart;
    });

    homeManagerModules = {
      morph-shell = import ./nix/hm-module.nix self;
      default = self.homeManagerModules.morph-shell;
    };

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
