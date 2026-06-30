#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="btpf/Alexandria"
APPIMAGE_NAME="Alexandria"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command jq
require_command makepkg
require_command sha256sum

latest_release_tag() {
  local headers

  headers="$(curl -fsSLI "https://github.com/${REPO}/releases/latest")"
  printf '%s\n' "${headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1
}

current_pkgver=""
current_pkgrel=""
current_sha256=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^[[:space:]]*sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "https://api.github.com/repos/${REPO}/releases/latest")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
else
  tag_name="$(latest_release_tag)"
fi

pkgver="${tag_name#v}"
asset_name="${APPIMAGE_NAME}_${pkgver}_amd64.AppImage"

if [[ -z "${tag_name}" || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
if [[ -n "${release_json}" ]]; then
  asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg asset_name "${asset_name}" '.assets[] | select(.name == $asset_name) | .browser_download_url' | head -n1)"
else
  asset_url="https://github.com/${REPO}/releases/download/${tag_name}/${asset_name}"
fi

if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve release asset: %s\n' "${asset_name}" >&2
  exit 1
fi

curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
trap - EXIT
rm -rf "${tmpdir}"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ && "${current_sha256}" == "${asset_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
else
  if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
    pkgrel="$((current_pkgrel + 1))"
  else
    pkgrel=1
  fi
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=alexandria-bin
_pkgname=alexandria
_appname=Alexandria
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Minimalistic ebook reader (prebuilt binary)'
arch=('x86_64')
url='https://github.com/btpf/Alexandria'
license=('unknown')
depends=('fuse2' 'gtk3' 'webkit2gtk-4.1')
provides=('alexandria')
conflicts=('alexandria')
options=('!strip')
source=("\${_appname}_\${pkgver}_amd64.AppImage::https://github.com/btpf/Alexandria/releases/download/${tag_name}/\${_appname}_\${pkgver}_amd64.AppImage")
sha256sums=('${asset_sha256}')

package() {
  local appimage="\${srcdir}/\${_appname}_\${pkgver}_amd64.AppImage"
  local extract_dir="\${srcdir}/appimage-extract"

  chmod +x "\${appimage}"
  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"

  (
    cd "\${extract_dir}"
    "\${appimage}" --appimage-extract >/dev/null
  )

  install -dm755 "\${pkgdir}/opt/\${_pkgname}"
  install -Dm755 "\${appimage}" "\${pkgdir}/opt/\${_pkgname}/\${_appname}_\${pkgver}_amd64.AppImage"
  install -dm755 "\${pkgdir}/usr/bin"
  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
exec /opt/alexandria/Alexandria_${pkgver}_amd64.AppImage "\$@"
SCRIPT
  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/applications/alexandria.desktop" "\${pkgdir}/usr/share/applications/alexandria.desktop"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/32x32/apps/alexandria.png" "\${pkgdir}/usr/share/icons/hicolor/32x32/apps/alexandria.png"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/128x128/apps/alexandria.png" "\${pkgdir}/usr/share/icons/hicolor/128x128/apps/alexandria.png"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/256x256@2/apps/alexandria.png" "\${pkgdir}/usr/share/icons/hicolor/256x256@2/apps/alexandria.png"
}
EOF

cd "${SCRIPT_DIR}"
makepkg --printsrcinfo > "${SRCINFO_PATH}"

printf '%s\n' "${pkgver}"
