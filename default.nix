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
  version = "0.5.0";
  src = ./.;

  # cargoSha256 = "0000000000000000000000000000000000000000000000000000";
  cargoSha256 = "sha256-LkphuWJsgCV4FV0AJehQaO8Xvnsn7/3MVCLSbBkecM4=";
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
