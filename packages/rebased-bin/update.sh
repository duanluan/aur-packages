#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="https://api.github.com/repos/DetachHead/rebased/releases/latest"
ASSET_NAME="rebased.tar.gz"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg
require_command sha256sum

current_pkgver=""
current_pkgrel=""
current_source_line=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_source_line="$(sed -n '/^source=/,/)/p' "${PKGBUILD_PATH}" | tr -d '\n')"
fi

release_json="$(curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg name "${ASSET_NAME}" '[.assets[] | select(.name == $name)][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r --arg name "${ASSET_NAME}" '[.assets[] | select(.name == $name)][0].digest')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve %s asset\n' "${ASSET_NAME}" >&2
  exit 1
fi

pkgbuild_asset_url="${asset_url/\/download\/${pkgver}\//\/download\/\$\{pkgver\}\/}"
source_line="source=(\"\${_pkgname}-\${pkgver}-\${CARCH}.tar.gz::${pkgbuild_asset_url}\")"

if [[ -z "${asset_digest}" || "${asset_digest}" == "null" ]]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL --retry 5 --retry-delay 2 --retry-all-errors "${asset_url}" -o "${tmpdir}/${ASSET_NAME}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${ASSET_NAME}" | awk '{print $1}')"
else
  asset_sha256="${asset_digest#sha256:}"
fi

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_source_line}" == "${source_line}" || "${current_source_line}" == *"rebased.tar.gz"* ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<'PKGBUILD_EOF'
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-bin
_pkgname=rebased
pkgver=__PKGVER__
pkgrel=__PKGREL__
pkgdesc='Standalone JetBrains-based Git client (prebuilt binary)'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
optdepends=('xdg-utils: open URLs from IDE')
provides=('rebased')
conflicts=('rebased')
options=('!strip')
source=("${_pkgname}-${pkgver}-${CARCH}.tar.gz::https://github.com/DetachHead/rebased/releases/download/${pkgver}/rebased.tar.gz")
sha256sums=('__ASSET_SHA256__')

package() {
  local app_dir="${srcdir}/idea-IC-261.25134.SNAPSHOT"
  local install_root="${pkgdir}/opt/${_pkgname}"

  install -dm755 "${install_root}"
  cp -a "${app_dir}/." "${install_root}/"

  install -Dm755 /dev/stdin "${pkgdir}/usr/bin/rebased" <<'SCRIPT'
#!/bin/sh
set -eu

plugin_src="/opt/rebased/plugins/localization-zh/lib/localization-zh.jar"
plugin_dst="${XDG_DATA_HOME:-${HOME}/.local/share}/detachhead/IdeaIC1.1/localization-zh.jar"

if [ -r "${plugin_src}" ]; then
  mkdir -p "$(dirname "${plugin_dst}")"
  if [ ! -f "${plugin_dst}" ] || ! cmp -s "${plugin_src}" "${plugin_dst}"; then
    cp "${plugin_src}" "${plugin_dst}"
  fi
fi

exec /opt/rebased/bin/idea "$@"
SCRIPT

  install -Dm644 "${app_dir}/bin/idea.svg" "${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  install -Dm644 "${app_dir}/bin/idea.png" "${pkgdir}/usr/share/pixmaps/rebased.png"
  install -Dm644 "${app_dir}/LICENSE.txt" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE.txt"

  install -Dm644 /dev/stdin "${pkgdir}/usr/share/applications/rebased.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Rebased
Comment=Standalone Git client based on IntelliJ platform
Exec=rebased %f
Icon=rebased
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-rebased
Categories=Development;IDE;VersionControl;
Keywords=git;vcs;jetbrains;
DESKTOP
}
PKGBUILD_EOF

sed -i \
  -e "s/__PKGVER__/${pkgver}/g" \
  -e "s/__PKGREL__/${pkgrel}/g" \
  -e "s/__ASSET_SHA256__/${asset_sha256}/g" \
  "${PKGBUILD_PATH}"

(cd "${SCRIPT_DIR}" && makepkg --printsrcinfo > "${SRCINFO_PATH}")
printf '%s\n' "${pkgver}"
