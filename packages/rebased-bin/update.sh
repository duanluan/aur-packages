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

current_pkgver=""
current_pkgrel=""
current_source_line=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_source_line="$(sed -n 's/^source=(.*$/&/p' "${PKGBUILD_PATH}" | head -n1)"
fi

release_json="$(curl -fsSL "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
asset_name="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "Rebased-x86_64.AppImage")][0].name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "Rebased-x86_64.AppImage")][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "Rebased-x86_64.AppImage")][0].digest')"
source_line="source=(\"\${_pkgname}-\${pkgver}-\${CARCH}.AppImage::${asset_url}\")"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve AppImage asset\n' >&2
  exit 1
fi

if [[ -z "${asset_digest}" || "${asset_digest}" == "null" ]]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
else
  asset_sha256="${asset_digest#sha256:}"
fi

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_source_line}" == "${source_line}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-bin
_pkgname=rebased
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Standalone JetBrains-based Git client (prebuilt binary)'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
optdepends=('xdg-utils: open URLs from the IDE')
provides=('rebased')
conflicts=('rebased')
options=('!strip')
source=("\${_pkgname}-\${pkgver}-\${CARCH}.AppImage::${asset_url}")
sha256sums=('${asset_sha256}')

package() {
  local appimage="\${srcdir}/\${_pkgname}-\${pkgver}-\${CARCH}.AppImage"
  local extract_dir="\${srcdir}/appimage-extract"

  chmod +x "\${appimage}"
  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"

  (
    cd "\${extract_dir}"
    APPIMAGE_EXTRACT_AND_RUN=1 "\${appimage}" --appimage-extract >/dev/null
  )

  install -dm755 "\${pkgdir}/opt/\${_pkgname}"
  install -Dm755 "\${appimage}" "\${pkgdir}/opt/\${_pkgname}/Rebased-x86_64.AppImage"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/rebased" <<'SCRIPT'
#!/bin/sh
exec env APPIMAGE_EXTRACT_AND_RUN=1 APPIMAGELAUNCHER_DISABLE=1 \\
  /opt/rebased/Rebased-x86_64.AppImage "\$@"
SCRIPT

  install -Dm644 "\${extract_dir}/squashfs-root/usr/bin/idea.svg" "\${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  install -Dm644 "\${extract_dir}/squashfs-root/rebased.png" "\${pkgdir}/usr/share/pixmaps/rebased.png"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/LICENSE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.txt"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/NOTICE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/NOTICE.txt"

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
X-AppImage-Version=${pkgver}
DESKTOP
}
EOF

cat > "${SRCINFO_PATH}" <<EOF
pkgbase = rebased-bin
	pkgdesc = Standalone JetBrains-based Git client (prebuilt binary)
	pkgver = ${pkgver}
	pkgrel = ${pkgrel}
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
	source = rebased-${pkgver}-x86_64.AppImage::${asset_url}
	sha256sums = ${asset_sha256}

pkgname = rebased-bin
EOF

printf '%s\n' "${pkgver}"
