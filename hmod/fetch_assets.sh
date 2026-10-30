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

# Downloads the Ozone assets, the sounds and the udev joypad profiles the hmod ships.
# Usage: fetch_assets.sh <libretro dir>
set -eu

dest="$1"
assets_ref=d9f969054dc7fbb6fa89519036d2b971e0855b51
autoconfig_ref=2f73cbf1f74904233f1c91a5c8e220565a880375

mkdir -p "$dest/assets" "$dest/joypad_autoconf"
curl -fsSL "https://codeload.github.com/libretro/retroarch-assets/tar.gz/$assets_ref" \
  | tar -xz --strip-components=1 -C "$dest/assets" --wildcards '*/ozone' '*/sounds'
rm -rf "$dest/assets/src"
curl -fsSL "https://codeload.github.com/libretro/retroarch-joypad-autoconfig/tar.gz/$autoconfig_ref" \
  | tar -xz --strip-components=1 -C "$dest/joypad_autoconf" --wildcards '*/udev'
# some upstream profiles use CRLF, which hmod-check rejects
find "$dest/joypad_autoconf" -name '*.cfg' -exec sed -i 's/\r$//' {} +
