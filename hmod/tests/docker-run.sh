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

# Starts run.sh in a BusyBox container with glibc, like the console. Arguments go to run.sh.
set -eu
export MSYS_NO_PATHCONV=1
repo=$(cd "$(dirname "$0")/../.." && { pwd -W 2> /dev/null || pwd; })
docker run --rm -v "$repo:/repo" busybox:1.36-glibc sh /repo/hmod/tests/run.sh "$@"
