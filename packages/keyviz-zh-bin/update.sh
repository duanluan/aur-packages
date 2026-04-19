#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
PKGVER="${PKGVER:-2.1.0}"
PKGREL="${PKGREL:-2}"
COMMIT="${COMMIT:-6cf089956a3448583074538de2f89f1a12c2ceae}"
SRC_DIR="keyviz-${COMMIT}"
SOURCE_URL="https://codeload.github.com/duanluan/keyviz/tar.gz/${COMMIT}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command makepkg
require_command sha256sum

tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

curl -fL "${SOURCE_URL}" -o "${tmpfile}" >/dev/null 2>&1
source_sha256="$(sha256sum "${tmpfile}" | cut -d " " -f1)"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=keyviz-zh-bin
pkgver=${PKGVER}
pkgrel=${PKGREL}
_commit=${COMMIT}
_srcdir="keyviz-\${_commit}"
pkgdesc='Chinese-localized fork of Keyviz with Linux fixes'
arch=('x86_64')
url='https://github.com/duanluan/keyviz'
license=('GPL3')
depends=('gtk3' 'libayatana-appindicator' 'webkit2gtk-4.1')
makedepends=('cargo' 'nodejs' 'npm')
provides=('keyviz')
conflicts=('keyviz' 'keyviz-bin' 'keyviz-cn-bin')
options=('!strip')
source=(
  "\${_srcdir}.tar.gz::${SOURCE_URL}"
)
sha256sums=(
  '${source_sha256}'
)

build() {
  cd "\${srcdir}/\${_srcdir}"

  export npm_config_cache="\${srcdir}/npm-cache"
  export CARGO_HOME="\${srcdir}/cargo-home"

  npm ci --cache "\${npm_config_cache}" --prefer-offline
  npm run tauri build -- --bundles deb
}

package() {
  local _builddir
  _builddir="\$(mktemp -d)"
  trap 'rm -rf "\${_builddir}"' EXIT

  bsdtar -C "\${_builddir}" -xf "\${srcdir}/\${_srcdir}/src-tauri/target/release/bundle/deb/keyviz_\${pkgver}_amd64.deb"
  bsdtar -C "\${pkgdir}" -xf "\${_builddir}/data.tar.gz"

  sed -i \
    -e 's/^Name=.*/Name=Keyviz 汉化版/' \
    -e 's/^Comment=.*/Comment=Keyviz 汉化版/' \
    -e 's/^Categories=.*/Categories=Utility;/' \
    "\${pkgdir}/usr/share/applications/keyviz.desktop"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${PKGVER}" "${PKGREL}"
