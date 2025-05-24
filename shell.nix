{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  name = "nervesShell";
  buildInputs = with pkgs; [
    elixir_1_18
    elixir-ls
    inotify-tools
    sqlite

    # runtime dependency of the app:
    exiftool
  ];

  PROJECT_ROOT = builtins.toString ./.;

  shellHook = ''
    alias vim=nvim
    export PATH=$PROJECT_ROOT/scripts:$PATH
  '';

  MIX_ARCHIVES = builtins.toString ./.mix_archives;
}
