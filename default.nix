{ pkgs ? import <nixpkgs> {} }:

let
  src = builtins.fetchGit {
    url = "https://github.com/ybycode/photor.git";
    rev = "test_nix_build";
  };

  myApp = pkgs.rustPlatform.buildRustPackage rec {
    name = "photor";
    version = "0.1.0";
    src = src;

    cargoSha256 = "sha256-nNwKDHJgjO4VFeIWAy6pB9+rFWr4JCsgC8Fu7g7nycA=";
    buildInputs = with pkgs; [ sqlite ];
  };

  wrapper = pkgs.writeShellScriptBin "${myApp.name}" ''
    # Add exiftool to the PATH
    export PATH="${pkgs.exiftool}/bin:$PATH"

    exec ${myApp}/bin/${myApp.name} "$@"
  '';

in {
  inherit myApp wrapper;
}
