#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/MrShellad/pilauncher/releases/latest}"
RELEASE_LATEST_URL="${RELEASE_LATEST_URL:-https://github.com/MrShellad/pilauncher/releases/latest}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

sha256_for_url() {
  local asset_url="$1"
  local asset_name="$2"
  local asset_digest="${3:-}"
  local tmpdir

  if [[ -n "${asset_digest}" && "${asset_digest}" != "null" ]]; then
    printf '%s\n' "${asset_digest#sha256:}"
    return 0
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}'
}

require_command curl
require_command jq
require_command makepkg
require_command sha256sum

current_pkgver=""
current_pkgrel=""
current_appimage_sha256=""
current_license_sha256=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  mapfile -t current_sha256s < <(sed -n "s/^[[:space:]]*'\\([0-9a-f]\\{64\\}\\)'.*/\\1/p" "${PKGBUILD_PATH}")
  current_appimage_sha256="${current_sha256s[0]:-}"
  current_license_sha256="${current_sha256s[1]:-}"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
  pkgver="${tag_name#v}"
  asset_name="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("PiLauncher_" + $version + "_amd64.AppImage"))][0].name')"
  asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("PiLauncher_" + $version + "_amd64.AppImage"))][0].browser_download_url')"
  asset_digest="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("PiLauncher_" + $version + "_amd64.AppImage"))][0].digest')"
else
  latest_headers="$(curl -fsSLI "${RELEASE_LATEST_URL}")"
  tag_name="$(printf '%s\n' "${latest_headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1)"
  pkgver="${tag_name#v}"
  asset_name="PiLauncher_${pkgver}_amd64.AppImage"
  asset_url="https://github.com/MrShellad/pilauncher/releases/download/${tag_name}/${asset_name}"
  asset_digest=""
fi

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "${tag_name}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 AppImage asset\n' >&2
  exit 1
fi

license_name="LICENSE"
license_url="https://raw.githubusercontent.com/MrShellad/pilauncher/main/LICENSE"

asset_sha256="$(sha256_for_url "${asset_url}" "${asset_name}" "${asset_digest}")"
curl -fL --retry 5 --retry-all-errors "${license_url}" -o "${SCRIPT_DIR}/${license_name}" >/dev/null 2>&1
license_sha256="$(sha256sum "${SCRIPT_DIR}/${license_name}" | awk '{print $1}')"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_appimage_sha256}" == "${asset_sha256}" && "${current_license_sha256}" == "${license_sha256}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=pilauncher-bin
_pkgname=pilauncher
_appname=PiLauncher
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Modern gamepad-friendly Minecraft launcher built with Tauri (prebuilt binary)'
arch=('x86_64')
url='https://github.com/MrShellad/pilauncher'
license=('custom')
depends=('fuse2' 'gtk3' 'webkit2gtk-4.1')
provides=('pilauncher')
conflicts=('pilauncher')
options=('!strip')
source=(
  "\${_appname}_\${pkgver}_amd64.AppImage::${asset_url}"
  'LICENSE'
)
noextract=("\${_appname}_\${pkgver}_amd64.AppImage")
sha256sums=(
  '${asset_sha256}'
  '${license_sha256}'
)

package() {
  local appimage="\${srcdir}/\${_appname}_\${pkgver}_amd64.AppImage"
  local extract_dir="\${srcdir}/appimage-extract"
  local desktop_source
  local icon_source

  chmod +x "\${appimage}"
  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"

  (
    cd "\${extract_dir}"
    APPIMAGE_EXTRACT_AND_RUN=1 "\${appimage}" --appimage-extract >/dev/null
  )

  install -dm755 "\${pkgdir}/opt/\${_pkgname}"
  install -Dm755 "\${appimage}" "\${pkgdir}/opt/\${_pkgname}/\${_appname}_\${pkgver}_amd64.AppImage"
  install -Dm644 "\${srcdir}/LICENSE" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/pilauncher" <<SCRIPT
#!/bin/sh
exec env APPIMAGE_EXTRACT_AND_RUN=1 APPIMAGELAUNCHER_DISABLE=1 \\\\
  /opt/\${_pkgname}/\${_appname}_\${pkgver}_amd64.AppImage "\\\$@"
SCRIPT

  desktop_source="\$(find "\${extract_dir}/squashfs-root" -type f -iname 'pilauncher.desktop' | head -n1)"
  if [[ -n "\${desktop_source}" ]]; then
    install -Dm644 "\${desktop_source}" "\${pkgdir}/usr/share/applications/pilauncher.desktop"
    sed -i \\
      -e 's|^Exec=.*|Exec=pilauncher %U|' \\
      -e 's|^Icon=.*|Icon=pilauncher|' \\
      -e 's|^Categories=.*|Categories=Game;|' \\
      "\${pkgdir}/usr/share/applications/pilauncher.desktop"
  else
    install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/pilauncher.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=PiLauncher
Comment=Modern gamepad-friendly Minecraft launcher
Exec=pilauncher %U
Icon=pilauncher
Terminal=false
StartupNotify=true
StartupWMClass=PiLauncher
Categories=Game;
Keywords=Minecraft;Launcher;PiLauncher;
X-AppImage-Version=${pkgver}
DESKTOP
  fi

  icon_source="\$(find "\${extract_dir}/squashfs-root" -type f \\( -iname 'pilauncher.png' -o -iname 'logo.png' \\) | head -n1)"
  if [[ -n "\${icon_source}" ]]; then
    install -Dm644 "\${icon_source}" "\${pkgdir}/usr/share/icons/hicolor/256x256/apps/pilauncher.png"
  fi
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
