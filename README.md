# photor (Photos Repository)

Photor is an application made to manage a large repository of photos ( > 1TB or more).

The "repository" is simply a collection of all photos, in directories named after the "create date" metadata of the photos, plus a db.sqlite file that stores metadata of each photo.

## Features (most aren't yet available):

- imports:

    - copy not yet already imported photos and videos into the repository,
    - extract metadata, save it to the database,
    - generate thumbnails.

- Viewing:

    - in the web browser,
    - metadata explorer and filters.

- culling

    - helper tools: eyes detection and sharpness calculation,
    - photos matches: 1 vs 1 or 3 or 4 at a time to sort photos of an album,
    - delayed deletion, to allow one to change their mind.

- backups management:

    - find what photos have not been backed up yet,
    - files selection to fill a backup medium, ex: 50 GB for a blu ray disc, 1.5 TB for a LTO5 tape.
    - shell scripts to drive disc or tape drives.

## Development

### Prerequisites

 - Elixir 1.18+
 - Phoenix 1.7+
 - SQLite3
 - ExifTool (for metadata extraction)

### Nix

(WIP)

