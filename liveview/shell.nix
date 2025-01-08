{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  name = "nervesShell";
  buildInputs = with pkgs; [
    elixir_1_18
    elixir-ls
    inotify-tools
    sqlite
  ];
  shellHook = ''
    alias vim=nvim
  '';

  MIX_ARCHIVES = builtins.toString ./.mix_archives;
}
