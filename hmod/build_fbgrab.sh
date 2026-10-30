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

# Cross-builds fbgrab (GPL-2.0, Gunnar Monell) for the clover scripts' screenshots.
# Usage: build_fbgrab.sh <output>
set -eu

output="$1"
cross="${CROSS_PREFIX:-arm-linux-gnueabihf-}"
ref=f43ce6d5ce48fb01360eaa7c4a92c2573a1d02f8
work="$(pwd)/out/fbgrab"

rm -rf "$work"
mkdir -p "$work"
curl -fsSL "https://raw.githubusercontent.com/GunnarMonell/fbgrab/$ref/fbgrab.c" -o "$work/fbgrab.c"
export PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabihf/pkgconfig
# shellcheck disable=SC2046
"${cross}gcc" -O2 -I/usr/include/arm-linux-gnueabihf -o "$work/fbgrab" "$work/fbgrab.c" $(pkg-config --cflags --libs libpng) -lz -lm
mkdir -p "$(dirname "$output")"
"${cross}strip" -o "$output" "$work/fbgrab"
