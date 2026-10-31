# RetroArch (S)NESCE

[![Build](https://github.com/DefKorns/RetroArch-S-NESCE/actions/workflows/hmod.yml/badge.svg)](https://github.com/DefKorns/RetroArch-S-NESCE/actions/workflows/hmod.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](../COPYING)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

A [hakchi](https://github.com/TeamShinkansen/Hakchi2-CE) hmod that puts a current [RetroArch](https://github.com/libretro/RetroArch) on the NES and SNES Classic, built from the source in this repository. It replaces the RetroArch 1.9.10 Ozone hmod and keeps its clover integration: saves, savestates, aspect ratio, bezels and the wrappers that send a game to RetroArch.

The cores live in a separate repository, [retroarch-snesce-cores](https://github.com/DefKorns/retroarch-snesce-cores), as one hmod per core.

> **Status:** early. It builds from source and the pieces were tested on a SNES Classic one by one (the RetroArch binary, the cores, `fbgrab` and the watchdog). Installing the hmod through Hakchi and launching games through the clover scripts is not tested end to end yet.

## Install

1. Uninstall the RetroArch 1.9.10 Ozone hmod (`_km_retroarch_1910_ozone`). Both install `/bin/retroarch`, so they cannot share a console.
2. Install `retroarch_snesce.hmod` with Hakchi like any other hmod.
3. Install at least one core from [retroarch-snesce-cores](https://github.com/DefKorns/retroarch-snesce-cores), for example `retroarch_snesce_core_snes9x2005.hmod` for SNES.

## Play

Add `--retroarch` to a game's command line in Hakchi, and `--core <name>` to pick the core (for example `--retroarch --core nestopia`). Without `--core`, NES games use `fceumm`, or `nestopia` for `.fds` and `.qd` when it is installed.

On the console, hold **Down** while launching a game to force RetroArch, or **Up** to force the original emulator. In a game, **Select + Start** opens the RetroArch menu.

SNES games from the console's own library come as `.sfrom` containers, which RetroArch cannot read: `retroarch-clover-child` extracts the ROM to `/tmp/rom` first, as `<game>.sfrom.sfc`, so the translation patches of [om_game-translations](https://github.com/DefKorns/om_game-translations) still find it. `/bin/snes` runs a game with Snes9x 2005.

Each core hmod also adds a `/bin` shortcut (`snes05`, `snes10`, `fceumm`, `nestopia`, `quicknes`) that can be used as a game's executable.

## What is included

- The RetroArch front end, built for the Classics (ARMv7 Cortex-A7, Mali-400, OpenGL ES 2) with the XMB and Ozone menus (XMB by default), the `gl` video driver and ALSA audio.
- The clover integration: `retroarch-clover`, `retroarch-clover-child`, `retroarch-mini`, the `clover-canoe-shvc` and `clover-kachikachi` wrappers, and the default `retroarch.cfg`.
- `retroarch_watchdog`, which ends RetroArch when the Reset button or a pad's Home button is pressed, and `fbgrab`, for the screenshot saved with a savestate.
- The Ozone and XMB (monochrome theme) assets and the sounds, and the udev joypad profiles, fetched at build time. The assets are the `assets.tar.gz` of [retroarch-snesce-cores](https://github.com/DefKorns/retroarch-snesce-cores) (the same files as the updater's `assets.zip`), checked against the `assets.tar.sha256` published next to it. The build always takes the assets published at that moment.

Not included: cores, shaders, BIOS files and the per-core configuration files of the 1.9.10 hmod.

## Differences from the 1.9.10 hmod

- **Threaded video is off.** On a SNES Classic, with Ozone, a newer RetroArch peaked at about 50 MB of RAM with threaded video against 29 MB for 1.9.10; with it off it peaked at about 26 MB. CPU use was at or below 1.9.10 in the same test.
- **Smaller feature set.** The build leaves out SDL2, RAR, CHD, zstd, bzip2, the video decoders and MaterialUI. See `hmod/build_retroarch.sh`.
- **RetroAchievements is built in but off.** Turn it on and log in at Settings, Achievements. It has not been tested on a console yet, and the build has no CHD support, so only cartridge systems get hashes.
- **The watchdog and `fbgrab` are built from source.** The watchdog is a rewrite whose output matched the original's for the Reset button and the pad. It is also written to read the Power switch of the SNES Classic, which the original could not access; that part is untested.

These numbers come from one console, two cores (Snes9x 2005 and 2010) and one game, with vsync on and sound off.

## Known limitations

- **Cores from the online updater are not tracked by Hakchi.** `retroarch.cfg` points the core updater at the [cores repository](https://github.com/DefKorns/retroarch-snesce-cores) and the build has TLS, but a core downloaded from the RetroArch menu is not an hmod, so Hakchi cannot update or remove it. Install cores as hmods if you want Hakchi to manage them. The online updater itself is not tested on a console yet.
- The `install` script and the clover scripts come from the 1.9.10 hmod and are only lightly changed.

## Build

You need Docker and git.

```sh
git submodule update --init
sh vendor/hmod-build/docker-make.sh -f Makefile.hmod hmod
```

The hmod is written to `out/retroarch_snesce.hmod`. The build runs in the [classicmini-cross-toolchain](https://github.com/DefKorns/classicmini-cross-toolchain) image, so the binaries link against the glibc and libstdc++ of the console.

## Branches and releases

- `master` only follows [libretro/RetroArch](https://github.com/libretro/RetroArch). It never carries this packaging.
- `hmod` holds the packaging. Update it with `git merge master` after syncing the fork.
- A tag `v*` on `hmod` builds the hmod and publishes a release.

## Contributing

[pre-commit](https://pre-commit.com/) checks the files you stage before each commit, in this folder and its workflow only. Set it up once per clone with `pip install pre-commit` and `pre-commit install`; `pre-commit run --all-files` checks everything.

## Credits

RetroArch is the work of the libretro team. The clover integration comes from the RetroArch 1.9.10 Ozone hmod, which builds on the work of ClusterM and ModMyClassic; see [CREDITS.md](CREDITS.md).

## License

GPL-3.0, like RetroArch. Each component keeps its own license: see [CREDITS.md](CREDITS.md).
