# To build:
#
#   $ nix-build -E '
#       with import <nixpkgs> {};
#       callPackage ./default.nix { }
#     '
{
  lib,
  pkgs,
  cacert,
  fetchFromGitHub,
  beamPackages,
  nix-update-script,
  stdenv,
  tailwindcss_3,
  esbuild,
}:

let

  pname = "photor-ex";
  version = "0.6.0";
  elixir = pkgs.elixir_1_18;
  src = ./.;
  runtimeDeps = with pkgs; [ bash exiftool imagemagick mozjpeg ];

in beamPackages.mixRelease {
  inherit
    pname
    version
    src
    elixir
    ;

  removeCookie = false;

  buildInputs = [
      # required for exqlite's compilation:
      stdenv # Or [ stdenv.cc ] if you only need compiler
    ];

  prePatch = ''
    rm -rf deps || true
  '';

  # this forces nixos executables of tailwind and esbuild in the configuration
  # of the project. They're both needed to build the assets of the phoenix app.
  # See nix packages of `plausible` and `firezone-server` where this is used the
  # same way.
  preBuild = ''
    cat >> config/config.exs <<EOF
    config :tailwind, path: "${lib.getExe tailwindcss_3}"
    config :esbuild, path: "${lib.getExe esbuild}"
    EOF
  '';

  postBuild = ''
    # for external task you need a workaround for the no deps check flag
    # https://github.com/phoenixframework/phoenix/issues/2690
    mix do deps.loadpaths --no-deps-check, assets.deploy
    mix do deps.loadpaths --no-deps-check, phx.digest priv/static
  '';

  # Set required environment variables
  MIX_ENV = "prod";
  HOME = "$TMPDIR";  # Crucial for Nix builds
  HEX_CACERTS_PATH = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  ERL_COMPILER_OPTIONS = "deterministic";  # For NIF compatibility

  stripDebug = true;

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "mix-deps-${pname}";
    inherit src version elixir;
    hash = "sha256-cHP4pS6ZTB4kN0bONA3C/cHem6HeM/OMVyY0X4b2o7U=";
    nativeBuildInputs = [ cacert stdenv ];
    HEX_CACERTS_PATH = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    # preConfigure = ''
    preBuild = ''
      # Remove existing deps directory if present
      rm -rf deps
      # build the assets:
      mix assets.deploy
    '';
  };

  postInstall = ''
    wrapProgram $out/bin/photor \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

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
