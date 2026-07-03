{
  description = "quoil desktop shell";

  # Pinned to the same commit as the system nixpkgs so the plugin builds
  # against the same Qt the system's qs binary links against.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/95ca1e203c0750115fd4a6f17d5a245dfe6b1edd";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
      nativeBuildInputs = with pkgs; [
        cmake
        ninja
        pkg-config
        qt6.wrapQtAppsHook
        clazy
      ];
      buildInputs = with pkgs; [
        qt6.qtbase
        qt6.qtdeclarative
        qt6.qtshadertools
        libqalculate
        pipewire
        aubio
        libcava
        fftw
        lm_sensors
        xkeyboard-config
      ];
      shellHook = ''
        export CAELESTIA_XKB_RULES_PATH="${pkgs.xkeyboard-config}/share/xkeyboard-config-2/rules/base.lst"
      '';
    };
  };
}
