with import <nixpkgs>
{
  overlays = [
    (import (fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz"))
  ];
};
let
  rustPlatform = makeRustPlatform {
    cargo = rust-bin.stable.latest.minimal;
    rustc = rust-bin.stable.latest.minimal;
  };
in
rustPlatform.buildRustPackage rec {
  name = "photor";
  version = "0.1.0";
  # src = ./.;
  src = builtins.fetchGit {
    url = "https://github.com/ybycode/photor.git";
    ref = "main";
    # rev = "8f509d51d797106f245e53957c0419f3c0bc59ee";
  };

  # cargoSha256 = "0000000000000000000000000000000000000000000000000000";
  cargoSha256 = "sha256-sD6DOQNsHtSIQk5uJE5BfyMHF0Vd8gH3qXZLQ4WtuUc=";
  buildInputs = with pkgs; [
    pkg-config
    openssl
    sqlite
  ];
  nativeBuildInputs = with pkgs; [
    openssl
    pkg-config
  ];
}
