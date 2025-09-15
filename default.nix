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
  pname = "photor";
  version = "0.5.2";
  src = ./.;

  # cargoSha256 = "0000000000000000000000000000000000000000000000000000";
  cargoHash = "sha256-fxD6gpDtqtJ0teI6Pdbr/WpidSxa3n+IemRe2GxFapI=";
  buildInputs = with pkgs; [
    makeWrapper # provides wrapProgram, see postInstall
    openssl
    sqlite
  ];

  nativeBuildInputs = with pkgs; [
    pkg-config
  ];

  # postInstall required to add the exiftool runtime dependency:
  postInstall = ''
     wrapProgram $out/bin/photor --set PATH ${lib.makeBinPath [ exiftool ]}
  '';
}
