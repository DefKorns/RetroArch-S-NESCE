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
# Cross-builds retroarch for the NES/SNES Classic (ARMv7 Cortex-A7, Mali fbdev, GLES2)
# in the classicmini-cross-toolchain image. Usage: build_retroarch.sh <output>
set -eu

output="$1"
cross="${CROSS_PREFIX:-arm-linux-gnueabihf-}"
root=$(pwd)
work="$root/out/ra-stubs"
egl_ref=e964211ff5f7c2bcada786954a16d5b813379395
gl_ref=6af574a14089ccfee87efe230ebcdd8742859813

fetch() {
  mkdir -p "$work/inc/$(dirname "$2")"
  curl -fsSL "https://raw.githubusercontent.com/KhronosGroup/$1/$3/api/$2" -o "$work/inc/$2"
}

rm -rf "$work"
mkdir -p "$work/lib"
for h in EGL/egl.h EGL/eglext.h EGL/eglplatform.h KHR/khrplatform.h; do
  fetch EGL-Registry "$h" "$egl_ref"
done
for h in GLES2/gl2.h GLES2/gl2ext.h GLES2/gl2platform.h GLES3/gl3.h GLES3/gl3platform.h; do
  fetch OpenGL-Registry "$h" "$gl_ref"
done
cp /opt/sdl2-headers/libudev.h "$work/inc/"
cp -r /usr/include/alsa "$work/inc/"

# the Mali blobs live on the console; empty stubs satisfy the linker
echo 'void ra_stub(void) {}' > "$work/stub.c"
for lib in libEGL.so libGLESv2.so libudev.so.1; do
  "${cross}gcc" -shared -Wl,-soname,"$lib" -o "$work/lib/$lib" "$work/stub.c"
done
ln -s libudev.so.1 "$work/lib/libudev.so"

arch="-marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard"
export CC="${cross}gcc" CXX="${cross}g++" AR="${cross}ar"
export CFLAGS="$arch -I$work/inc"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$work/lib -L/usr/lib/arm-linux-gnueabihf -Wl,--unresolved-symbols=ignore-all"

./configure --host="${cross%-}" --disable-wayland --disable-x11 --disable-opengl \
  --disable-opengl1 --disable-opengl_core --enable-mali_fbdev --disable-freetype \
  --enable-opengles --enable-udev --enable-alsa --enable-neon --enable-floathard \
  --disable-discord --disable-rwebm --disable-rmp4 --disable-rav1 --disable-rvp9 --disable-rmpeg1 \
  --disable-sdl2 --enable-ssl --enable-retrossl --disable-oss --disable-cdrom --disable-chd \
  --disable-rchd --disable-rrar --disable-rzstd --disable-rbzip2 --disable-rdds --disable-rwebp \
  --disable-rtga --disable-rbmp --disable-mcp --disable-networkgamepad \
  --disable-materialui --disable-translate --disable-accessibility --disable-gamemode
make HAVE_CLASSIC=1 HAVE_C_A7A7=1 HAVE_HAKCHI=1 -j"$(nproc)"

mkdir -p "$(dirname "$output")"
"${cross}strip" -o "$output" retroarch
