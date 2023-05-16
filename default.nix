{ pkgs ? import <nixpkgs> {} }:

let
  myApp = pkgs.rustPlatform.buildRustPackage rec {
    name = "photor";
    version = "0.1.0";
    src = pkgs.lib.cleanSource ./.;

    cargoSha256 = "sha256-nNwKDHJgjO4VFeIWAy6pB9+rFWr4JCsgC8Fu7g7nycA=";
    buildInputs = with pkgs; [ sqlite pkg-config ];
  };

  wrapper = pkgs.writeShellScriptBin "${myApp.name}" ''
    # Add exiftool to the PATH
    export PATH="${pkgs.exiftool}/bin:$PATH"

    exec ${myApp}/bin/${myApp.name} "$@"
  '';

in {
  inherit myApp wrapper;
}
