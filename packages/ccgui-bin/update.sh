#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/zhukunpenglinyutong/desktop-cc-gui/releases/latest}"
RELEASE_LATEST_URL="${RELEASE_LATEST_URL:-https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases/latest}"

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
  local attempt

  if [[ -n "${asset_digest}" && "${asset_digest}" != "null" ]]; then
    printf '%s\n' "${asset_digest#sha256:}"
    return 0
  fi

  if [[ -f "${SCRIPT_DIR}/${asset_name}" ]]; then
    sha256sum "${SCRIPT_DIR}/${asset_name}" | awk '{print $1}'
    return 0
  fi

  tmpdir="$(mktemp -d)"

  for attempt in 1 2 3 4 5; do
    if curl -fL --retry 3 --retry-all-errors -C - "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1; then
      sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}'
      rm -rf "${tmpdir}"
      return 0
    fi
  done

  rm -rf "${tmpdir}"
  printf 'failed to download asset after retries: %s\n' "${asset_name}" >&2
  return 1
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
  asset_name="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("ccgui_" + $version + "_amd64.AppImage"))][0].name')"
  asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("ccgui_" + $version + "_amd64.AppImage"))][0].browser_download_url')"
  asset_digest="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("ccgui_" + $version + "_amd64.AppImage"))][0].digest')"
else
  latest_headers="$(curl -fsSLI "${RELEASE_LATEST_URL}")"
  tag_name="$(printf '%s\n' "${latest_headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1)"
  pkgver="${tag_name#v}"
  asset_name="ccgui_${pkgver}_amd64.AppImage"
  asset_url="https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases/download/${tag_name}/${asset_name}"
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

pkgbuild_asset_url="${asset_url/\/download\/${tag_name}\//\/download\/v\$\{pkgver\}\/}"
pkgbuild_asset_url="${pkgbuild_asset_url/${asset_name}/\$\{_appname\}_\$\{pkgver\}_amd64.AppImage}"
license_name="LICENSE"
license_url="https://raw.githubusercontent.com/zhukunpenglinyutong/desktop-cc-gui/${tag_name}/LICENSE"

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

pkgname=ccgui-bin
_pkgname=ccgui
_appname=ccgui
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Next-generation VibeCoding editor (prebuilt binary)'
arch=('x86_64')
url='https://github.com/zhukunpenglinyutong/desktop-cc-gui'
license=('MIT')
depends=('gtk3' 'webkit2gtk-4.1' 'gst-plugins-base-libs' 'gst-plugins-good')
provides=('ccgui')
conflicts=('ccgui')
options=('!strip')
source=(
  "\${_appname}_\${pkgver}_amd64.AppImage::${pkgbuild_asset_url}"
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

  chmod +x "\${appimage}"
  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"

  (
    cd "\${extract_dir}"
    APPIMAGE_EXTRACT_AND_RUN=1 "\${appimage}" --appimage-extract >/dev/null
  )

  install -Dm755 "\${extract_dir}/squashfs-root/usr/bin/cc-gui" \\
    "\${pkgdir}/opt/\${_pkgname}/usr/bin/cc-gui"
  install -Dm755 "\${extract_dir}/squashfs-root/usr/bin/cc_gui_daemon" \\
    "\${pkgdir}/opt/\${_pkgname}/usr/bin/cc_gui_daemon"
  install -Dm644 "\${srcdir}/LICENSE" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/ccgui" <<SCRIPT
#!/bin/sh
export GDK_BACKEND="\\\${GDK_BACKEND:-x11}"
exec /opt/\${_pkgname}/usr/bin/cc-gui "\\\$@"
SCRIPT

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s ccgui "\${pkgdir}/usr/bin/cc-gui"

  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/32x32/apps/cc-gui.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/32x32/apps/ccgui.png"
  install -Dm644 "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/128x128/apps/cc-gui.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/128x128/apps/ccgui.png"
  install -Dm644 "\${extract_dir}/squashfs-root/ccgui.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/256x256/apps/ccgui.png"

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/ccgui.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=ccgui
Comment=Next-generation VibeCoding editor
Exec=ccgui %U
Icon=ccgui
Terminal=false
StartupNotify=true
StartupWMClass=cc-gui
Categories=Development;IDE;
Keywords=AI;Claude Code;Codex;Gemini;Opencode;ccgui;
X-AppImage-Version=\${pkgver}
DESKTOP
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
