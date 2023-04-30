# photor (Photos Repository)

## Development

Start nix-shell to prepare the development environment. It'll bring rust,
sqlite3 etc. (see default.nix):

```bash
$ nix-shell
[nix-shell:~/code/photor]$
```

### Database migrations

```bash
$ diesel migration generate some_new_migration
$ diesel migration run
$ # or, to rollback and run again (to quickly iterate on a migration script):
$ diesel migration redo
```

### Run the code in dev mode

```bash
cargo run -- --help
```
