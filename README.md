# uBird

Resources to build uBlock Origin for Thunderbird.

Builds can be found [here](https://gitlab.com/celenityy/uBird/-/tree/main/outputs). In particular, the latest build can always be found [here](https://gitlab.com/celenityy/uBird/-/raw/main/outputs/uBird_latest.xpi).

## Why?

[For unclear reasons](https://github.com/gorhill/uBlock/commit/e016a63f7bfa9f80ad14c6c4ce21db2d26396556), uBlock Origin stopped creation of Thunderbird CI builds upstream. However, the scripts/resources to build Thunderbird still remain in their repo; so this project leverages those existing scripts/resources to continue creating builds of uBlock Origin for Thunderbird.

Currently, the only change to uBlock Origin's source code made by this repo is to change the add-on ID from `uBlock0@raymondhill.net` to `uBird@celenity.dev`.

## Building

First, you'll need to run `scripts/get_sources.sh` to get the sources for uBlock Origin and uAssets:

*The version and commit of uBlock Origin are specified at `scripts/versions.sh`.*

```sh
./scripts/get_sources.sh
```

Now, simply run `scripts/build.sh`:

```sh
./scripts/build.sh
```

And that's it! Your `.xpi` files will be under the `outputs` directory.

## Licensing

Contents of this repo are licensed under the [GNU General Public License v3.0 or later](https://spdx.org/licenses/GPL-3.0-or-later.html) *(`GPL-3.0-or-later`)* where applicable.

uBlock Origin is licensed under the [GNU General Public License v3.0](https://github.com/gorhill/uBlock/blob/master/LICENSE.txt) *(`GPL-3.0`)*.

## Notices

This repo has no affiliation with uBlock Origin.
