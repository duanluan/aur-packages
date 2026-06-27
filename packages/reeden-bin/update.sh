#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
DOWNLOAD_PAGE_URL="${DOWNLOAD_PAGE_URL:-https://reeden.app/cn/download}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command makepkg
require_command perl
require_command sha256sum

current_pkgver=""
current_pkgrel=""
current_sha256=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^[[:space:]]*sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

page_html="$(curl -fsSL -A 'Mozilla/5.0' "${DOWNLOAD_PAGE_URL}")"
asset_url="$(
  printf '%s\n' "${page_html}" |
    perl -0ne 'print "$1\n" if m{(https://download\.reeden\.app/Reeden/[^"<> ]+/Reeden-[^"<> ]+-linux-x86_64\.deb)}'
)"
asset_url="${asset_url%%$'\n'*}"

if [[ -z "${asset_url}" ]]; then
  printf 'failed to resolve Reeden Linux deb URL\n' >&2
  exit 1
fi

asset_name="${asset_url##*/}"
pkgver="${asset_url#https://download.reeden.app/Reeden/}"
pkgver="${pkgver%%/*}"

if [[ -z "${pkgver}" || -z "${asset_name}" ]]; then
  printf 'failed to resolve Reeden version from URL: %s\n' "${asset_url}" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null
asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"

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

pkgname=reeden-bin
_pkgname=reeden
_appname=Reeden
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Modern cross-platform ebook reader (prebuilt binary)'
arch=('x86_64')
url='https://reeden.app/cn/download'
license=('unknown')
depends=('gtk3' 'libayatana-appindicator' 'sqlite' 'xdg-user-dirs')
provides=('reeden')
conflicts=('reeden')
options=('!strip')
source=("\${_appname}-\${pkgver}-linux-x86_64.deb::https://download.reeden.app/\${_appname}/\${pkgver}/\${_appname}-\${pkgver}-linux-x86_64.deb")
sha256sums=('${asset_sha256}')

package() {
  local _extractdir

  _extractdir="\$(mktemp -d)"
  trap 'rm -rf "\${_extractdir}"' EXIT

  bsdtar -C "\${_extractdir}" -xf "\${srcdir}/\${_appname}-\${pkgver}-linux-x86_64.deb"
  bsdtar -C "\${pkgdir}" -xf "\${_extractdir}/data.tar.zst"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s '/usr/share/reeden/reeden' "\${pkgdir}/usr/bin/reeden"

  sed -i \\
    -e 's/^Categories=.*/Categories=Office;Viewer;/' \\
    "\${pkgdir}/usr/share/applications/reeden.desktop"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf 'updated reeden-bin to %s-%s\n' "${pkgver}" "${pkgrel}"
