{
  description = "quoil desktop shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
