#!/bin/sh
#  Copyright (C) 2026 DefKorns (https://defkorns.github.io/LICENSE)
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Runs retroarch-clover-child in a BusyBox container with stand-ins for retroarch,
# mount and the rest, and compares what it does with hmod/tests/golden.
# Usage: sh hmod/tests/run.sh [--update]   (docker-run.sh starts it in the container)
# shellcheck disable=SC2329 # the scn* functions are called as "scn$s"
set -u

# it deletes /etc/libretro, /etc/preinit and more, so it only runs in the container
[ -f /.dockerenv ] || {
  echo "run.sh replaces system folders: start it with docker-run.sh" >&2
  exit 1
}

repo="${REPO:-/repo}"
mod="$repo/hmod/mod"
tests="$repo/hmod/tests"
child="$mod/bin/retroarch-clover-child"
out=/tmp/out
mode=compare
[ "${1:-}" = "--update" ] && mode=update

byte() {
  # shellcheck disable=SC2059 # the format is the octal escape built by the inner printf
  printf "$(printf '\\%03o' "$1")"
}

u32le() {
  byte $(($1 & 255))
  byte $((($1 >> 8) & 255))
  byte $((($1 >> 16) & 255))
  byte $((($1 >> 24) & 255))
}

# a 48 byte header, a 64 byte ROM and a footer that holds the ROM size
make_sfrom() {
  {
    printf 'HDRHDRHD'
    u32le 48
    printf 'HDRHDRHD'
    u32le 112
    printf 'HDRHDRHDHDRHDRHDHDRHDRHD'
    printf 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz!?'
    printf 'F'
    u32le 64
  } > "$1"
}

resetFs() {
  # shellcheck disable=SC2114 # a throwaway container
  rm -rf /etc/libretro /var/cache/retroarch /tmp/rom /tmp/log /tmp/cfg_orig /tmp/overlay_orig \
    /games /saves /media /var/lib/clover /usr/share/games /var/squashfs /stubs /etc/preinit
  mkdir -p /etc/libretro/core /etc/libretro/system /games /saves /var/lib/clover/profiles/0 /stubs /var/cache
  cp -r "$mod/etc/libretro/." /etc/libretro/
  for core in snes9x2005 snes9x2010 fceumm nestopia mame2003; do
    printf 'FAKE-CORE-%s' "$core" > "/etc/libretro/core/${core}_libretro.so"
  done
  cp "$tests"/stubs/* /stubs/
  cp /etc/libretro/retroarch.cfg /tmp/cfg_orig
  cp -r /etc/libretro/overlay /tmp/overlay_orig
  : > /tmp/log
  : > /tmp/log.retroarch
  : > /tmp/log.watchdog
  : > /tmp/log.fbgrab
  cat > /etc/preinit <<'PRE'
script_init() { :; }
modname=retroarch_snesce
gamepath=/usr/share/games
cfg_ra_write_test=n
mount_bind() { echo "mount_bind $*" >> /tmp/log; }
PRE
}

showFiles() {
  find /var/cache/retroarch /tmp/rom /saves /games /media -mindepth 1 2> /dev/null | sort | while read -r f; do
    if [ -L "$f" ]; then
      echo "  L $f -> $(readlink "$f")"
    elif [ -d "$f" ]; then
      echo "  D $f"
    else
      echo "  F $f ($(wc -c < "$f") bytes) $(head -c 24 "$f" | tr -c '[:print:]' '.')"
    fi
  done
}

# runChild <scenario> <child arguments>: the stubs and the files left behind are written to $out/<scenario>.txt
runChild() {
  name="$1"
  shift
  {
    echo "## child $*"
    PATH="/stubs:$PATH" sh "$child" "$@" 2>&1
    echo "## exit $?"
    echo "## log"
    cat /tmp/log
    echo "## retroarch"
    cat /tmp/log.retroarch
    echo "## watchdog"
    cat /tmp/log.watchdog
    echo "## fbgrab"
    cat /tmp/log.fbgrab
    echo "## after"
    echo "cfg-diff:"
    diff /tmp/cfg_orig /etc/libretro/retroarch.cfg
    echo "overlay-diff:"
    diff -r /tmp/overlay_orig /etc/libretro/overlay
    echo "files:"
    showFiles
  } > "$out/$name.txt"
}

scnSnesBasic() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  printf 'old-sram' > /saves/CLV-P-VAAAJ/data.sram
  printf 'state0' > /saves/CLV-P-VAAAJ/suspend
  export RA_WRITE_AUTOSAVE=1 RA_WRITE_SRAM=1
  runChild snes_basic snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --title-code CLV-P-VAAAJ \
    --save-data-backing-file /saves/CLV-P-VAAAJ/data.sram --save-on-quit /saves/CLV-P-VAAAJ/out/suspend \
    --load-state-file /saves/CLV-P-VAAAJ/suspend
}

scnSnesSfrom() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  make_sfrom /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfrom
  runChild snes_sfrom snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfrom --title-code CLV-P-VAAAJ \
    --save-data-backing-file /saves/CLV-P-VAAAJ/data.sram
}

scnNesFds() {
  mkdir -p /games/CLV-P-HAAAJ /saves/CLV-P-HAAAJ
  printf 'FDS' > /games/CLV-P-HAAAJ/game.fds
  printf 'old-sram' > /saves/CLV-P-HAAAJ/data.sram
  export RA_WRITE_SRAM=1
  runChild nes_fds nestopia /games/CLV-P-HAAAJ/game.fds --save-data-backing-file /saves/CLV-P-HAAAJ/data.sram
}

scnFceummFds() {
  mkdir -p /games/CLV-P-HAAAJ /saves/CLV-P-HAAAJ
  printf 'FDS' > /games/CLV-P-HAAAJ/game.fds
  printf 'old-sram' > /saves/CLV-P-HAAAJ/data.sram
  runChild fceumm_fds fceumm /games/CLV-P-HAAAJ/game.fds --save-data-backing-file /saves/CLV-P-HAAAJ/data.sram
}

scnNosaves() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild nosaves snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --ra-nosaves
}

scnBezel() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild bezel snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --bezel-mode --video-mode keep-aspect-ratio \
    --no-scanlines --no-smooth
}

scnCrt() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild crt snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --video-mode crt-filter
}

scnFilters() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild filters snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --enable-scanlines --smooth43
}

scnExtra() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild extra snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --ra-extra --ips=/x.ips
}

scnXz() {
  cp "$tests/fixtures/core.xz" /etc/libretro/core/km_test_libretro.so
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild xz_core km_test /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
}

scnIps() {
  game=/usr/share/games/CLV-P-VAAAJ
  real=/var/squashfs$game
  mkdir -p "$game" "$real" /tmp/rom
  printf 'ROM' > /tmp/rom/rom.sfc
  printf 'IPS' > "$real/patch.ips"
  printf 'BPS' > "$real/patch.bps"
  printf 'Exec=/usr/bin/clover-canoe-shvc -rom %s/CLV-P-VAAAJ.sfrom --volume 100
' "$real" > "$game/CLV-P-VAAAJ.desktop"
  runChild ips snes9x2005 /tmp/rom/rom.sfc --title-code CLV-P-VAAAJ
}

scnWatchdog() {
  mkdir -p /games/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  export RA_SLEEP=3 WD_OUTPUT="key reset 1"
  runChild watchdog snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
}

scnMame() {
  mkdir -p /games/CLV-Z-MAME /saves/CLV-Z-MAME/mame2003
  printf 'ROM' > /games/CLV-Z-MAME/game.zip
  printf 'NV' > /saves/CLV-Z-MAME/mame2003/nv
  printf 'BIOS' > /etc/libretro/system/neogeo_old.zip
  runChild mame mame2003 /games/CLV-Z-MAME/game.zip --save-data-backing-file /saves/CLV-Z-MAME/data.sram
}

scnScreenshot() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  runChild screenshot snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --save-screenshot-on-quit /saves/CLV-P-VAAAJ/shot.png
}

scnStatesSd() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  sed -i 's/cfg_ra_write_test=n/cfg_ra_write_test=y/' /etc/preinit
  export RA_WRITE_STATE=1
  runChild states_sd snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --save-data-backing-file /saves/CLV-P-VAAAJ/data.sram
}

scnStatesNand() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  export RA_WRITE_STATE=1
  runChild states_nand snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --save-data-backing-file /saves/CLV-P-VAAAJ/data.sram
}

scnStatesForceNand() {
  mkdir -p /games/CLV-P-VAAAJ /saves/CLV-P-VAAAJ
  printf 'ROM' > /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc
  sed -i 's/cfg_ra_write_test=n/cfg_ra_write_test=y/' /etc/preinit
  export RA_WRITE_STATE=1
  runChild states_force_nand snes9x2005 /games/CLV-P-VAAAJ/CLV-P-VAAAJ.sfc --save-data-backing-file /saves/CLV-P-VAAAJ/data.sram --nand-states
}

rm -rf "$out"
mkdir -p "$out"
scenarios="SnesBasic SnesSfrom NesFds FceummFds Nosaves Bezel Crt Filters Extra Xz Ips Watchdog Mame Screenshot StatesSd StatesNand StatesForceNand"
for s in $scenarios; do
  (
    resetFs
    "scn$s"
  )
done

fail=0
for f in "$out"/*.txt; do
  name="$(basename "$f")"
  if [ "$mode" = update ]; then
    cp "$f" "$tests/golden/$name"
    echo "updated $name"
  elif diff -u "$tests/golden/$name" "$f" > "$out/$name.diff" 2>&1; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    cat "$out/$name.diff"
    fail=1
  fi
done
exit "$fail"
