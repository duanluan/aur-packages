#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/duanluan/wuyou-toolkit-releases/releases/latest}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg

release_json="$(curl -fsSL "${RELEASE_API_URL}")"
tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
pkgver="${tag_name#v}"
asset_name="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("wuyou-toolkit_" + $version + "_amd64.deb"))][0].name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("wuyou-toolkit_" + $version + "_amd64.deb"))][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("wuyou-toolkit_" + $version + "_amd64.deb"))][0].digest')"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 deb asset\n' >&2
  exit 1
fi

if [[ -n "${asset_digest}" && "${asset_digest}" != "null" ]]; then
  asset_sha256="${asset_digest#sha256:}"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=wuyou-toolkit-bin
_pkgname=wuyou-toolkit
pkgver=${pkgver}
pkgrel=1
pkgdesc='Native shell for wuyou-toolkit (prebuilt binary)'
arch=('x86_64')
url='https://github.com/duanluan/wuyou-toolkit-releases'
license=('unknown')
depends=('gtk3' 'webkit2gtk-4.1')
provides=('wuyou-toolkit')
conflicts=('wuyou-toolkit')
options=('!strip')
source=("\${_pkgname}_\${pkgver}_amd64.deb::${asset_url}")
sha256sums=('${asset_sha256}')

package() {
  local _extractdir
  _extractdir="\$(mktemp -d)"
  trap 'rm -rf "\${_extractdir}"' EXIT

  bsdtar -C "\${_extractdir}" -xf "\${srcdir}/\${_pkgname}_\${pkgver}_amd64.deb"
  bsdtar -C "\${pkgdir}" -xf "\${_extractdir}/data.tar.gz"

  sed -i \
    -e 's/^Name=.*/Name=Wuyou Toolkit/' \
    -e 's/^Comment=.*/Comment=Cross-platform desktop toolbox/' \
    -e 's/^Categories=.*/Categories=Utility;Development;/' \
    "\${pkgdir}/usr/share/applications/wuyou-toolkit.desktop"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
