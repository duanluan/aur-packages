#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO_API_URL="${REPO_API_URL:-https://api.github.com/repos/duanluan/keyviz}"
BRANCH="${BRANCH:-}"
COMMIT="${COMMIT:-}"

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
require_command tar

current_pkgver=""
current_pkgrel=""
current_commit=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_commit="$(sed -n 's/^_commit=//p' "${PKGBUILD_PATH}" | head -n1)"
fi

if [[ -z "${BRANCH}" || -z "${COMMIT}" ]]; then
  repo_json="$(curl -fsSL "${REPO_API_URL}")"

  if [[ -z "${BRANCH}" ]]; then
    BRANCH="$(printf '%s\n' "${repo_json}" | jq -r '.default_branch')"
  fi

  if [[ -z "${COMMIT}" ]]; then
    COMMIT="$(
      curl -fsSL "${REPO_API_URL}/commits/${BRANCH}" |
        jq -r '.sha'
    )"
  fi
fi

if [[ -z "${BRANCH}" || "${BRANCH}" == "null" ]]; then
  printf 'failed to resolve default branch\n' >&2
  exit 1
fi

if [[ -z "${COMMIT}" || "${COMMIT}" == "null" ]]; then
  printf 'failed to resolve latest commit\n' >&2
  exit 1
fi

SRC_DIR="keyviz-${COMMIT}"
SOURCE_URL="https://codeload.github.com/duanluan/keyviz/tar.gz/${COMMIT}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL "${SOURCE_URL}" -o "${tmpdir}/source.tar.gz" >/dev/null 2>&1
source_sha256="$(sha256sum "${tmpdir}/source.tar.gz" | cut -d " " -f1)"

tar -xzf "${tmpdir}/source.tar.gz" -C "${tmpdir}"
source_root="${tmpdir}/${SRC_DIR}"
PKGVER="${PKGVER:-$(jq -r '.version' "${source_root}/src-tauri/tauri.conf.json")}"

if [[ -z "${PKGVER}" || "${PKGVER}" == "null" ]]; then
  printf 'failed to resolve package version\n' >&2
  exit 1
fi

if [[ -n "${PKGREL:-}" ]]; then
  pkgrel="${PKGREL}"
elif [[ "${current_pkgver}" == "${PKGVER}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_commit}" == "${COMMIT}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=keyviz-zh-bin
pkgver=${PKGVER}
pkgrel=${pkgrel}
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
  "\${_srcdir}.tar.gz::https://codeload.github.com/duanluan/keyviz/tar.gz/\${_commit}"
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

printf '%s-%s\n' "${PKGVER}" "${pkgrel}"
