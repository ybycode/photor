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
  version = "0.4.1";
  src = ./.;

  # cargoSha256 = "0000000000000000000000000000000000000000000000000000";
  cargoSha256 = "sha256-9kYfvuCVysUzQib0veAPtHHazjiVLu7bvKNq5IRTHkY=";
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
