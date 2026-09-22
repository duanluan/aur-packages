#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/esengine/DeepSeek-Reasonix/releases?per_page=10}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"

# Find the latest release with a tag starting with "desktop-v"
desktop_release="$(printf '%s\n' "${release_json}" | jq '[.[] | select(.tag_name | startswith("desktop-v"))][0]')"
tag_name="$(printf '%s\n' "${desktop_release}" | jq -r '.tag_name')"
pkgver="${tag_name#desktop-v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest desktop release tag\n' >&2
  exit 1
fi

asset_name="$(printf '%s\n' "${desktop_release}" | jq -r '[.assets[] | select(.name == "Reasonix-linux-amd64.deb")][0].name')"
asset_url="$(printf '%s\n' "${desktop_release}" | jq -r '[.assets[] | select(.name == "Reasonix-linux-amd64.deb")][0].browser_download_url')"

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 deb asset\n' >&2
  exit 1
fi

# Keep the current pkgrel when the release tag is unchanged, so a manual
# packaging fix is not silently reset to pkgrel=1 by the daily refresh.
pkgrel=1
if [[ -f "${PKGBUILD_PATH}" ]]; then
  old_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -1)"
  old_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -1)"
  if [[ "${old_pkgver}" == "${pkgver}" && "${old_pkgrel}" =~ ^[0-9]+$ ]]; then
    pkgrel="${old_pkgrel}"
  fi
fi

# Download and compute sha256
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=reasonix-desktop-bin
_pkgname=reasonix-desktop
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Terminal-native AI coding agent with DeepSeek API (Electron desktop GUI, repackaged from .deb)'
arch=('x86_64')
url='https://github.com/esengine/DeepSeek-Reasonix'
license=('MIT')
# The bundle ships its own pinned Electron runtime; these are only the
# shared-library / desktop-integration dependencies it loads at runtime.
depends=('alsa-lib' 'at-spi2-core' 'cairo' 'dbus' 'gcc-libs' 'glib2' 'gtk3'
         'hicolor-icon-theme' 'libcups' 'libnotify' 'libx11' 'libxcb'
         'libxcomposite' 'libxdamage' 'libxext' 'libxfixes' 'libxkbcommon'
         'libxrandr' 'libxss' 'mesa' 'nss' 'pango' 'systemd-libs' 'xdg-utils')
provides=('reasonix-desktop')
conflicts=('reasonix-desktop' 'deepseek-reasonix-desktop' 'deepseek-reasonix-desktop-bin')
options=('!strip' '!debug')
source=("\${_pkgname}_\${pkgver}_amd64.deb::\${url}/releases/download/desktop-v\${pkgver}/Reasonix-linux-amd64.deb")
noextract=("\${_pkgname}_\${pkgver}_amd64.deb")
sha256sums=('${asset_sha256}')

prepare() {
  mkdir -p "\${srcdir}/debroot"
  bsdtar -xf "\${srcdir}/\${_pkgname}_\${pkgver}_amd64.deb" -C "\${srcdir}/debroot"
  # Upstream switched data.tar.gz to data.tar.xz in newer releases;
  # extract whichever member the .deb actually carries.
  bsdtar -xf "\${srcdir}/debroot"/data.tar.* -C "\${srcdir}/debroot"
}

package() {
  cd "\${srcdir}/debroot"
  install -d "\${pkgdir}/usr/lib/reasonix" "\${pkgdir}/usr/bin"

  # Electron shell with its pinned runtime
  cp -a --no-preserve=ownership usr/lib/reasonix/app "\${pkgdir}/usr/lib/reasonix/"
  chmod 755 "\${pkgdir}/usr/lib/reasonix/app"

  # The desktop service resolves app/Reasonix and its private CLI beside
  # itself; keep all three binaries together under /usr/lib/reasonix. The
  # private reasonix CLI must NOT go to /usr/bin — that path belongs to the
  # separate reasonix TUI packages.
  local _bin
  for _bin in reasonix reasonix-desktop reasonix-launcher; do
    install -Dm755 "usr/bin/\${_bin}" "\${pkgdir}/usr/lib/reasonix/\${_bin}"
  done
  ln -s ../lib/reasonix/reasonix-desktop "\${pkgdir}/usr/bin/reasonix-desktop"
  ln -s ../lib/reasonix/reasonix-launcher "\${pkgdir}/usr/bin/reasonix-launcher"

  # Chromium SUID sandbox helper; without root:root 4755 the app can only
  # start with --no-sandbox
  chmod 4755 "\${pkgdir}/usr/lib/reasonix/app/chrome-sandbox"

  # Desktop entry — upstream's Exec=reasonix-launcher is installed above.
  # Native Wayland windows map to StartupWMClass "Reasonix" (case-sensitive).
  install -Dm644 usr/share/applications/reasonix.desktop \\
    "\${pkgdir}/usr/share/applications/reasonix.desktop"
  sed -i 's/^StartupWMClass=.*/StartupWMClass=Reasonix/' \\
    "\${pkgdir}/usr/share/applications/reasonix.desktop"

  # Icons
  local _icon _dir
  for _icon in usr/share/icons/hicolor/*/apps/reasonix-desktop.*; do
    _dir="\$(basename "\$(dirname "\$(dirname "\${_icon}")")")"
    install -Dm644 "\${_icon}" \\
      "\${pkgdir}/usr/share/icons/hicolor/\${_dir}/apps/\$(basename "\${_icon}")"
  done
  install -Dm644 usr/share/pixmaps/reasonix-desktop.png \\
    "\${pkgdir}/usr/share/pixmaps/reasonix-desktop.png"

  # License shipped inside the bundle
  install -Dm644 usr/lib/reasonix/app/LICENSE \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"

  # Deliberately not installed: reasonix-update-helper and its polkit action —
  # pacman owns upgrades, and an in-app self-update would overwrite tracked
  # files and corrupt the package.
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
