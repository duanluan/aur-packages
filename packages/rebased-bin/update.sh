#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="https://api.github.com/repos/DetachHead/rebased/releases/latest"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq

release_json="$(curl -fsSL "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
asset_name="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name | test("^ideaIC-.*\\.tar\\.gz$"))][0].name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name | test("^ideaIC-.*\\.tar\\.gz$"))][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name | test("^ideaIC-.*\\.tar\\.gz$"))][0].digest')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve linux tarball asset\n' >&2
  exit 1
fi

build="${asset_name#ideaIC-}"
build="${build%.tar.gz}"

if [[ -z "${asset_digest}" || "${asset_digest}" == "null" ]]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
else
  asset_sha256="${asset_digest#sha256:}"
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-bin
_pkgname=rebased
pkgver=${pkgver}
_build=${build}
pkgrel=1
pkgdesc='Standalone JetBrains-based Git client (prebuilt binary)'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
optdepends=('xdg-utils: open URLs from the IDE')
provides=('rebased')
conflicts=('rebased')
options=('!strip')
source=("\${_pkgname}-\${pkgver}.tar.gz::${asset_url}")
sha256sums=('${asset_sha256}')

package() {
  install -dm755 "\${pkgdir}/opt/\${_pkgname}"
  cp -a "\${srcdir}/idea-IC-${build}/." "\${pkgdir}/opt/\${_pkgname}/"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${_pkgname}/bin/idea" "\${pkgdir}/usr/bin/rebased"

  install -Dm644 "\${srcdir}/idea-IC-${build}/bin/idea.svg" "\${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  install -Dm644 "\${srcdir}/idea-IC-${build}/bin/idea.png" "\${pkgdir}/usr/share/pixmaps/rebased.png"
  install -Dm644 "\${srcdir}/idea-IC-${build}/LICENSE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.txt"
  install -Dm644 "\${srcdir}/idea-IC-${build}/NOTICE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/NOTICE.txt"

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/rebased.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Version=1.0
Name=Rebased
Comment=Standalone Git client based on the IntelliJ platform
Exec=rebased %f
Icon=rebased
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-rebased
Categories=Development;IDE;VersionControl;
Keywords=git;vcs;jetbrains;
DESKTOP
}
EOF

cat > "${SRCINFO_PATH}" <<EOF
pkgbase = rebased-bin
	pkgdesc = Standalone JetBrains-based Git client (prebuilt binary)
	pkgver = ${pkgver}
	pkgrel = 1
	url = https://github.com/DetachHead/rebased
	arch = x86_64
	license = Apache-2.0
	depends = fontconfig
	depends = giflib
	depends = hicolor-icon-theme
	depends = libdbusmenu-glib
	depends = ttf-font
	optdepends = xdg-utils: open URLs from the IDE
	provides = rebased
	conflicts = rebased
	options = !strip
	source = rebased-${pkgver}.tar.gz::${asset_url}
	sha256sums = ${asset_sha256}

pkgname = rebased-bin
EOF

printf '%s\n' "${pkgver}"
