# Credits

The RetroArch front end and its libretro cores are built from their own sources: [libretro/RetroArch](https://github.com/libretro/RetroArch) and the cores listed in [retroarch-snesce-cores](https://github.com/DefKorns/retroarch-snesce-cores).

The clover integration in `hmod/mod` (the `retroarch-clover*` and `retroarch-mini` scripts, the `clover-canoe-shvc` and `clover-kachikachi` wrappers, the preinit script, `retroarch.cfg` and its overlays and filters) is copied from the RetroArch 1.9.10 Ozone hmod. That work goes back through several authors, all under the GPL:

- [ClusterM](https://github.com/ClusterM/retroarch-clover): the original `retroarch-clover` module for hakchi, with the scripts that save states and saves and start RetroArch from the Clover UI (2017-2018).
- [Classicmods / ModMyClassic](https://github.com/Classicmods/RA_Platform-Hakchi): the RetroArch platform for the NES and SNES Classic (2018-2019).
- KMFDManic, madmonkey, bslenul and DanTheMan827: the RetroArch 1.9.10 Ozone hmod (2021-2022), which extended the scripts with bezels, overclocking, shared saves and the configuration this hmod starts from.

`retroarch_watchdog` is a rewrite in `hmod/src`, written against the output of the original binary that came with the 1.9.10 hmod. `fbgrab` is built from [GunnarMonell/fbgrab](https://github.com/GunnarMonell/fbgrab) (GPL-2.0).

I could not tell which of the last group wrote which lines, because the scripts carry no author headers. If a line here is yours and the credit is wrong, tell me and I will fix it.
