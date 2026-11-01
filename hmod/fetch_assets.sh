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

# Downloads the assets (Ozone, XMB monochrome theme and sounds, cut down by retroarch-snesce-cores)
# and the udev joypad profiles the hmod ships. ASSETS_URL overrides where the assets come from.
# Usage: fetch_assets.sh <libretro dir>
set -eu

dest="$1"
assets_url="${ASSETS_URL:-https://defkorns.github.io/retroarch-snesce-cores/frontend/assets.tar.gz}"
autoconfig_ref=2f73cbf1f74904233f1c91a5c8e220565a880375

mkdir -p "$dest/assets" "$dest/joypad_autoconf"
curl -fsSL -o "$dest/assets.tar.gz" "$assets_url"
curl -fsSL -o "$dest/assets.tar.sha256" "${assets_url%.gz}.sha256"
gzip -dc "$dest/assets.tar.gz" > "$dest/assets.tar"
echo "$(cat "$dest/assets.tar.sha256")  $dest/assets.tar" | sha256sum -c -
tar -xf "$dest/assets.tar" -C "$dest/assets"
rm -f "$dest/assets.tar.gz" "$dest/assets.tar" "$dest/assets.tar.sha256"
# the legacy /bin names of the cores, read by retroarch-shortcuts; without it only the core names get a shortcut
curl -fsSL -o "$dest/shortcuts.list" "${assets_url%/*}/shortcuts.list" || echo "no shortcuts.list at ${assets_url%/*}" >&2
curl -fsSL "https://codeload.github.com/libretro/retroarch-joypad-autoconfig/tar.gz/$autoconfig_ref" \
  | tar -xz --strip-components=1 -C "$dest/joypad_autoconf" --wildcards '*/udev'
# some upstream profiles use CRLF, which hmod-check rejects
find "$dest/joypad_autoconf" -name '*.cfg' -exec sed -i 's/\r$//' {} +
