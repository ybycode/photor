{ pkgs ? import <nixpkgs> {} }:

let
  myApp = pkgs.rustPlatform.buildRustPackage rec {
    name = "photor";
    version = "0.1.0";
    src = builtins.fetchGit {
      url = "https://github.com/ybycode/photor.git";
      ref = "main";
      # rev = "8f509d51d797106f245e53957c0419f3c0bc59ee";
    };

    # cargoSha256 = "0000000000000000000000000000000000000000000000000000";
    cargoSha256 = "sha256-/RsFK/7raNq8cgHfIZhGG1LfpOgsQ2eVRrhu3AFgTsQ=";
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
