#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="Shrey113/Android-Dex"
ASSET_NAME="android_dex_linux.tar.gz"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "$@"
}

latest_release_tag() {
  local headers

  headers="$(curl -fsSLI "https://github.com/${REPO}/releases/latest")"
  printf '%s\n' "${headers}" |
    sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' |
    tail -n1
}

require_command awk
require_command curl
require_command makepkg
require_command sed
require_command sha256sum

tag_name="${TAG_NAME:-$(latest_release_tag)}"
if [[ -z "${tag_name}" ]]; then
  printf 'failed resolve latest Android-Dex release tag\n' >&2
  exit 1
fi

pkgver="${tag_name#Android-Dex-v.}"
if [[ "${pkgver}" == "${tag_name}" ]]; then
  pkgver="${tag_name#Android-Dex-v}"
fi
if [[ "${pkgver}" == "${tag_name}" ]]; then
  pkgver="${tag_name#v}"
fi
if [[ -z "${pkgver}" || "${pkgver}" == "${tag_name}" ]]; then
  printf 'failed parse pkgver from tag: %s\n' "${tag_name}" >&2
  exit 1
fi

asset_url="https://github.com/${REPO}/releases/download/${tag_name}/${ASSET_NAME}"
source_file="android-dex-${pkgver}.tar.gz"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

if [[ -f "${SCRIPT_DIR}/${source_file}" ]]; then
  asset_path="${SCRIPT_DIR}/${source_file}"
else
  asset_path="${tmpdir}/${source_file}"
  curl_retry --output "${asset_path}" "${asset_url}"
fi

asset_sha256="$(sha256sum "${asset_path}" | awk '{print $1}')"

current_pkgver=""
current_pkgrel=""
current_sha256=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^[[:space:]]*sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_sha256}" == "${asset_sha256}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
pkgname=android-dex-bin
_pkgname=android-dex
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Transform Android devices into a desktop experience (prebuilt Linux bundle)'
arch=('x86_64')
url='https://github.com/Shrey113/Android-Dex'
license=('unknown')
depends=(
  'bash'
  'ffmpeg'
  'gtk3'
  'libayatana-appindicator'
  'libdecor'
  'libepoxy'
  'libjxl'
  'librist'
  'libnsl'
  'numactl'
  'libusb'
  'libxrandr'
  'libxss'
  'mesa'
  'mpg123'
  'rav1e'
  'sdl2'
  'svt-av1'
  'zenity'
)
optdepends=(
  'android-udev: Android USB device permissions'
  'kdialog: KDE file picker dialogs'
)
provides=('android-dex')
conflicts=('android-dex')
options=('!strip' '!lto')
source=("\${_pkgname}-\${pkgver}.tar.gz::https://github.com/${REPO}/releases/download/${tag_name}/${ASSET_NAME}")
sha256sums=('${asset_sha256}')

package() {
  local app_dir="\${srcdir}/android_dex"
  local install_root="\${pkgdir}/opt/\${_pkgname}"

  install -dm755 "\${install_root}"
  cp -a "\${app_dir}/." "\${install_root}/"

  install -dm755 "\${install_root}/lib"
  ln -s /usr/lib/libjxl.so "\${install_root}/lib/libjxl.so.0.7"
  ln -s /usr/lib/libjxl_threads.so "\${install_root}/lib/libjxl_threads.so.0.7"
  ln -s /usr/lib/librav1e.so "\${install_root}/lib/librav1e.so.0"
  ln -s /usr/lib/libSvtAv1Enc.so "\${install_root}/lib/libSvtAv1Enc.so.1"
  ln -s /usr/lib/librist.so "\${install_root}/lib/librist.so.4"
  ln -s /usr/lib/libnuma.so "\${install_root}/lib/libnuma.so.1"
  sed -i 's/^chmod +x "\\$APP_BINARY"$/true/' "\${install_root}/run_android_dex.sh"

  chmod 755 "\${install_root}/android_dex_win" "\${install_root}/run_android_dex.sh"
  if [[ -d "\${install_root}/Build_copy/adb-linux" ]]; then
    chmod 755 "\${install_root}/Build_copy/adb-linux/adb" "\${install_root}/Build_copy/adb-linux/scrcpy"
  fi

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
cd /opt/android-dex || exit 1
exec ./run_android_dex.sh "\$@"
SCRIPT

  install -Dm644 "\${app_dir}/data/flutter_assets/assets/big_app_icon.png" "\${pkgdir}/usr/share/pixmaps/\${_pkgname}.png"

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/\${_pkgname}.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Android DEX
Comment=Transform Android devices into a desktop experience
Exec=android-dex
Icon=android-dex
Terminal=false
Categories=Utility;RemoteAccess;
StartupNotify=true
DESKTOP
}
EOF

(cd "${SCRIPT_DIR}" && makepkg --printsrcinfo > "${SRCINFO_PATH}")
printf '%s\n' "${pkgver}"
