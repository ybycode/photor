# To build:
#
#   $ nix-build -E '
#       with import <nixpkgs> {};
#       callPackage ./default.nix {
#         inherit (beamPackages) fetchMixDeps mixRelease;
#       }
#     '
{
  lib,
  pkgs,
  cacert,
  fetchFromGitHub,
  fetchMixDeps,
  mixRelease,
  nix-update-script,
  stdenv,
}:

let
  pname = "photor-ex";
  version = "0.5.4";
  elixir = pkgs.elixir_1_18;
  src = ./.;
  # src = builtins.path {
  #   path = ./.;
  #   name = "${pname}-src";
  #   filter = path: type:
  #     builtins.baseNameOf path != "deps";
  # };
  # src = fetchFromGitHub {
  #   owner = "ybycode";
  #   repo = "elixir-ls";
  #   rev = "v${version}";
  #   hash = "sha256-y1QT+wRFc+++OVFJwEheqcDIwaKHlyjbhEjhLJ2rYaI=";
  # };
in
mixRelease {
  inherit
    pname
    version
    src
    elixir
    ;

  removeCookie = false;

  # required for exqlite:
  buildInputs = [ stdenv ];  # Or [ stdenv.cc ] if you only need compiler

  prePatch = ''
    rm -rf deps || true
  '';

  # Set required environment variables
  MIX_ENV = "prod";
  HOME = "$TMPDIR";  # Crucial for Nix builds
  HEX_CACERTS_PATH = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  ERL_COMPILER_OPTIONS = "deterministic";  # For NIF compatibility

  stripDebug = true;

  mixFodDeps = fetchMixDeps {
    pname = "mix-deps-${pname}";
    inherit src version elixir;
    hash = "sha256-cHP4pS6ZTB4kN0bONA3C/cHem6HeM/OMVyY0X4b2o7U=";
    nativeBuildInputs = [ cacert stdenv ];
    HEX_CACERTS_PATH = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    # preConfigure = ''
    preBuild = ''
      # Remove existing deps directory if present
      rm -rf deps
    '';
  };

  meta = with lib; {
    homepage = "https://github.com/ybycode/photor";
    description = ''
    '';
    longDescription = ''
    '';
    license = licenses.agpl3Plus;
    platforms = platforms.unix;
    mainProgram = "photor-ex";
    # maintainers = teams.beam.members;
  };
  passthru.updateScript = nix-update-script { };
}
