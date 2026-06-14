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

# Download and compute sha256
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=reasonix-desktop-deb
_pkgname=reasonix-desktop
pkgver=${pkgver}
pkgrel=1
pkgdesc='Terminal-native AI coding agent with DeepSeek API (desktop GUI, repackaged from .deb)'
arch=('x86_64')
url='https://github.com/esengine/DeepSeek-Reasonix'
license=('MIT')
depends=('gtk3' 'webkit2gtk-4.1')
provides=('reasonix-desktop')
conflicts=('reasonix-desktop' 'deepseek-reasonix-desktop' 'deepseek-reasonix-desktop-bin')
options=('!strip')
source=("\${_pkgname}_\${pkgver}_amd64.deb::https://github.com/esengine/DeepSeek-Reasonix/releases/download/desktop-v\${pkgver}/Reasonix-linux-amd64.deb")
sha256sums=('${asset_sha256}')

package() {
  local _extractdir
  _extractdir="\$(mktemp -d)"
  trap 'rm -rf "\${_extractdir}"' EXIT

  bsdtar -C "\${_extractdir}" -xf "\${srcdir}/\${_pkgname}_\${pkgver}_amd64.deb"
  bsdtar -C "\${_extractdir}" -xf "\${_extractdir}/data.tar.gz"

  # Install the real binary under /opt/reasonix-desktop
  install -Dm755 "\${_extractdir}/usr/bin/reasonix-desktop" \\
    "\${pkgdir}/opt/reasonix-desktop/reasonix-desktop"

  # Wrapper script — mirrors Wails' own Linux initialisation logic
  # GDK_BACKEND: only force x11 when not on Wayland (Wails does this internally too)
  # WEBKIT_DISABLE_DMABUF_RENDERER: avoids KMS/GBM failures on NVIDIA/mesa combos
  # WEBKIT_DISABLE_COMPOSITING_MODE: forces software compositing (fixes blank webview)
  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/reasonix-desktop" <<'SCRIPT'
#!/bin/sh
if [ -z "\${GDK_BACKEND:-}" ]; then
	case "\${XDG_SESSION_TYPE:-}" in
		wayland) ;;
		*) export GDK_BACKEND=x11 ;;
	esac
fi
export WEBKIT_DISABLE_DMABUF_RENDERER="\${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
export WEBKIT_DISABLE_COMPOSITING_MODE="\${WEBKIT_DISABLE_COMPOSITING_MODE:-1}"
exec /opt/reasonix-desktop/reasonix-desktop "\$@"
SCRIPT

  # Desktop entry
  install -Dm644 "\${_extractdir}/usr/share/applications/reasonix.desktop" \\
    "\${pkgdir}/usr/share/applications/reasonix.desktop"
  sed -i \\
    -e 's/^Name=.*/Name=Reasonix/' \\
    -e 's/^Comment=.*/Comment=Terminal-native AI coding agent with DeepSeek API/' \\
    -e 's/^Categories=.*/Categories=Development;Utility;/' \\
    "\${pkgdir}/usr/share/applications/reasonix.desktop"

  # Icon
  install -Dm644 "\${_extractdir}/usr/share/pixmaps/reasonix-desktop.png" \\
    "\${pkgdir}/usr/share/pixmaps/reasonix-desktop.png"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
