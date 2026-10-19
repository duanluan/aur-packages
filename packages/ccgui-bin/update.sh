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

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_appimage_sha256="$(sed -n "s/^[[:space:]]*'\\([0-9a-f]\\{64\\}\\)'.*/\\1/p" "${PKGBUILD_PATH}" | head -n1)"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# 上游资产前缀变过名（ccgui_ -> CC.GUI_），所以不拼固定文件名，
# 而是取 release 里唯一以 _amd64.AppImage 结尾的资产（.sig 结尾不同，不会匹配）
release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
  asset_json="$(printf '%s\n' "${release_json}" | jq -c '[.assets[] | select(.name | endswith("_amd64.AppImage"))][0]')"
  asset_name="$(printf '%s\n' "${asset_json}" | jq -r '.name')"
  asset_url="$(printf '%s\n' "${asset_json}" | jq -r '.browser_download_url')"
  asset_digest="$(printf '%s\n' "${asset_json}" | jq -r '.digest')"
else
  latest_headers="$(curl -fsSLI "${RELEASE_LATEST_URL}")"
  tag_name="$(printf '%s\n' "${latest_headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1)"
  asset_name=""
  asset_url=""
  asset_digest=""
  for candidate in "CC.GUI_${tag_name#v}_amd64.AppImage" "ccgui_${tag_name#v}_amd64.AppImage"; do
    candidate_url="https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases/download/${tag_name}/${candidate}"
    if curl -fsSLI -o /dev/null "${candidate_url}"; then
      asset_name="${candidate}"
      asset_url="${candidate_url}"
      break
    fi
  done
fi

pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "${tag_name}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 AppImage asset\n' >&2
  exit 1
fi

# PKGBUILD 里的下载地址必须保留上游真实资产名（前缀会变），
# 只把 tag 和版本号换成 ${pkgver} 变量；本地文件名另用别名（source 的 :: 前缀）
asset_name_template="${asset_name/${pkgver}/\$\{pkgver\}}"
pkgbuild_asset_url="${asset_url/\/download\/${tag_name}\//\/download\/v\$\{pkgver\}\/}"
pkgbuild_asset_url="${pkgbuild_asset_url/${asset_name}/${asset_name_template}}"

asset_sha256="$(sha256_for_url "${asset_url}" "${asset_name}" "${asset_digest}")"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_appimage_sha256}" == "${asset_sha256}" ]]; then
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
pkgdesc='Multi-engine AI coding desktop client (prebuilt binary)'
arch=('x86_64')
url='https://github.com/zhukunpenglinyutong/desktop-cc-gui'
license=('NOASSERTION')
depends=('gtk3' 'webkit2gtk-4.1' 'gst-plugins-base-libs' 'gst-plugins-good')
provides=('ccgui')
conflicts=('ccgui')
options=('!strip')
source=(
  "\${_appname}_\${pkgver}_amd64.AppImage::${pkgbuild_asset_url}"
)
noextract=("\${_appname}_\${pkgver}_amd64.AppImage")
sha256sums=(
  '${asset_sha256}'
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

  install -Dm755 "\${extract_dir}/squashfs-root/usr/bin/ccgui-next" \\
    "\${pkgdir}/opt/\${_pkgname}/usr/bin/ccgui-next"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/ccgui" <<SCRIPT
#!/bin/sh
export GDK_BACKEND="\\\${GDK_BACKEND:-x11}"
exec /opt/\${_pkgname}/usr/bin/ccgui-next "\\\$@"
SCRIPT

  ln -s ccgui "\${pkgdir}/usr/bin/ccgui-next"
  ln -s ccgui "\${pkgdir}/usr/bin/cc-gui"

  local icon_src icon_size
  for icon_src in "\${extract_dir}/squashfs-root/usr/share/icons/hicolor/"*"/apps/ccgui-next.png"; do
    [[ -e "\${icon_src}" ]] || continue
    icon_size="\${icon_src#*squashfs-root/usr/share/icons/hicolor/}"
    icon_size="\${icon_size%/apps/ccgui-next.png}"
    install -Dm644 "\${icon_src}" "\${pkgdir}/usr/share/icons/hicolor/\${icon_size}/apps/\${_appname}.png"
  done

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/ccgui.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=CC GUI
Comment=Multi-engine AI coding desktop client
Exec=ccgui %U
Icon=ccgui
Terminal=false
StartupNotify=true
StartupWMClass=ccgui-next
Categories=Development;IDE;
Keywords=AI;Claude Code;Codex;Gemini;OpenCode;DeepSeek;ccgui;
X-AppImage-Version=\${pkgver}
DESKTOP
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
