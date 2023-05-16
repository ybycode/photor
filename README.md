# photor (Photos Repository)

## Features

- [ ] Create a repository of photos, defined by:
  - [ ] A directory
  - [ ] An sqlite database
- [ ] Import photos from a directory (e.g. mounted SD card) into the repository:
  - [ ] Calculate a partial checksum of each photo found
  - [ ] Copy the photo file if the partial checksum is not found in the database
  - Options:
    - [ ] Recursive, default true

## Development

Start nix-shell to prepare the development environment. It'll bring rust,
sqlite3 etc. (see default.nix):

```bash
$ nix-shell
[nix-shell:~/code/photor]$
```

## Build

```
$ nix-build -A wrapper
```

## Installation

```
$ nix-env -f default.nix -iA wrapper
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
