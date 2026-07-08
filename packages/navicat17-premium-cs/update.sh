#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_NOTES_URL='https://www.navicat.com.cn/products/navicat-premium-release-note'
SOURCE_URL_X86_64='https://dn.navicat.com/download/navicat17-premium-cs-x86_64.AppImage'
SOURCE_URL_AARCH64='https://dn.navicat.com/download/navicat17-premium-cs-aarch64.AppImage'

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command rg
require_command sha256sum
require_command makepkg

release_notes_html="$(curl -fsSL "${RELEASE_NOTES_URL}")"
pkgver="$(
  rg -o -P -m1 '(?<=Navicat Premium \(Linux\) version )\d+\.\d+\.\d+' \
    <<<"${release_notes_html}"
)"
current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" 2>/dev/null || true)"
current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" 2>/dev/null || true)"

if [[ -z "${pkgver}" ]]; then
  printf 'failed resolve latest Linux release\n' >&2
  exit 1
fi

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
else
  pkgrel=1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

download_sha256() {
  local url="$1"
  local filename="$2"

  curl -fL --retry 5 --retry-delay 2 --retry-all-errors "${url}" -o "${tmpdir}/${filename}" >/dev/null 2>&1
  sha256sum "${tmpdir}/${filename}" | awk '{print $1}'
}

asset_sha256_x86_64="$(download_sha256 "${SOURCE_URL_X86_64}" 'navicat17-premium-cs-x86_64.AppImage')"
asset_sha256_aarch64="$(download_sha256 "${SOURCE_URL_AARCH64}" 'navicat17-premium-cs-aarch64.AppImage')"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=navicat17-premium-cs
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Navicat Premium is a multi-connection database development tool. (Chinese Simplified)'
arch=('x86_64' 'aarch64')
url='https://www.navicat.com.cn/products/navicat-premium'
license=('NOASSERTION')
options=('!strip')
source_x86_64=("navicat17-premium-cs-x86_64-\${pkgver}.AppImage::${SOURCE_URL_X86_64}")
source_aarch64=("navicat17-premium-cs-aarch64-\${pkgver}.AppImage::${SOURCE_URL_AARCH64}")
sha256sums_x86_64=('${asset_sha256_x86_64}')
sha256sums_aarch64=('${asset_sha256_aarch64}')

package() {
  cd "\${srcdir}"

  chmod +x "\${srcdir}/navicat17-premium-cs-\${CARCH}-\${pkgver}.AppImage"
  "\${srcdir}/navicat17-premium-cs-\${CARCH}-\${pkgver}.AppImage" --appimage-extract

  install -dm755 "\${pkgdir}/opt/\${pkgname}"
  cp -a "\${srcdir}/squashfs-root/." "\${pkgdir}/opt/\${pkgname}/"

  # Prefer Arch's system copies low-level libraries to avoid
  # symbol-version conflicts with host libmount/libudev users.
  rm -f \\
    "\${pkgdir}/opt/\${pkgname}/usr/lib/libsystemd.so"* \\
    "\${pkgdir}/opt/\${pkgname}/usr/lib/libudev.so"* \\
    "\${pkgdir}/opt/\${pkgname}/usr/lib/libblkid.so"* \\
    "\${pkgdir}/opt/\${pkgname}/usr/lib/libselinux.so"*

  install -Dm644 "\${srcdir}/squashfs-root/usr/share/applications/navicat.desktop" \\
    "\${pkgdir}/usr/share/applications/navicat.desktop"
  install -Dm644 "\${srcdir}/squashfs-root/usr/share/icons/hicolor/256x256/apps/navicat-icon.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/256x256/apps/navicat-icon.png"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${pkgname}/AppRun" "\${pkgdir}/usr/bin/navicat"

  sed -i \\
    -e 's|^Exec=.*|Exec=navicat %U|' \\
    -e 's|^Icon=.*|Icon=navicat-icon|' \\
    -e 's|^Categories=.*|Categories=Development;Database;|' \\
    "\${pkgdir}/usr/share/applications/navicat.desktop"
}
EOF

(cd "${SCRIPT_DIR}" && makepkg --printsrcinfo > "${SRCINFO_PATH}")

printf '%s\n' "${pkgver}"
