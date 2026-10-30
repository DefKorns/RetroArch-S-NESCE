# RetroArch (S)NESCE

RetroArch built from this repository for the NES and SNES Classic (ARMv7 Cortex-A7, Mali-400, OpenGL ES 2), with the clover integration of the 1.9.10 hmod: games launched with `--retroarch`, saves, savestates, aspect ratio, bezels and the Famicom Mini / Super Famicom wrappers.

It replaces the RetroArch 1.9.10 Ozone hmod. Uninstall that one first: both install `/bin/retroarch`.

Differences from the 1.9.10 hmod:

- Threaded video is off, which takes about 24 MB less RAM.
- No cores, systems or per-core configs are included. Cores come as one hmod per core (with its `/bin` shortcut) or through the online updater; see retroarch-snesce-cores. Compressed (`xz`) `km_*` cores still load through `retroarch-clover`.

The clover integration (scripts, config and assets) comes from the RetroArch 1.9.10 Ozone hmod, which builds on ClusterM's retroarch-clover and the ModMyClassic RetroArch platform for the Classics; the hmod itself is by KMFDManic, madmonkey, bslenul and DanTheMan827. RetroArch and `fbgrab` are built from their own sources. See `hmod/CREDITS.md` in the repository.
