# photor (Photos Repository)

## Development

Start nix-shell to prepare the development environment. It'll bring rust,
sqlite3 etc. (see shell.nix):

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

### Troubleshooting

At some point the installation was failing with:
```
error: this derivation has bad 'meta.outputsToInstall'
```

Running `$ nix-env -u --always` solved the problem.

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

# Features / TODO

## General

- [ ] show the CLI help when no arguments are given
- [ ] clean code mess ¯\_(ツ)_/¯

## Database

- [x] integration of migrations files in the build
- [ ] database initialization command
- [x] database migration command

To be added in the DB for each photo:

- [x] exif: original date
- [x] exif: camera make
- [x] exif: camera model
- [x] file size
- [x] sha256sum

## Maintenance

- [ ] check if all photos in database have their corresponding file on disk
- [ ] check that files on disk match the data in DB (+ checksum check)
- [ ] command to rebuild / complete database entries missing data

## Repository

- [ ] command to output simple stats:
  - [ ] size on disk
  - [ ] number of files (photos / videos)
  - [ ] last time since maintenance run

## Disc burn utilities

- [ ] FUSE mount of files listed after DB query
- [ ] photos selection from start date / photo DB id that fits on a disc of some capacity
- [ ] see xorriso integration or input generation

## Web server

- [ ] generate thumbnails of pictures
- [ ] serve the repository for reading via HTTP
- [ ] photos tournament to find the best ones
