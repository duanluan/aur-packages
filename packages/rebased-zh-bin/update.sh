#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="https://api.github.com/repos/DetachHead/rebased/releases/latest"
PLUGIN_SCRIPT_URL="https://raw.githubusercontent.com/duanluan/shell-scripts/main/prepare-jetbrains-zh-plugin.sh"
PLUGIN_SOURCE_PATH="${SCRIPT_DIR}/assets/localization-zh-source.jar"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

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

download_file() {
  local url="$1"
  local output_path="$2"

  curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "${output_path}" "${url}"
}

current_pkgver=""
current_pkgrel=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
fi

[[ -f "${PLUGIN_SOURCE_PATH}" ]] || {
  printf 'missing plugin source: %s\n' "${PLUGIN_SOURCE_PATH}" >&2
  exit 1
}

release_json="$(curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
if [[ "${pkgver}" == "${current_pkgver}" && -n "${current_pkgrel}" ]]; then
  pkgrel="${current_pkgrel}"
else
  pkgrel=1
fi
asset_url="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "rebased.tar.gz")][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "rebased.tar.gz")][0].digest')"
asset_sha256="${asset_digest#sha256:}"
plugin_output_dir="${SCRIPT_DIR}/assets/${pkgver}"
plugin_output_path="${plugin_output_dir}/localization-zh.jar"

mkdir -p "${plugin_output_dir}"
download_file "${asset_url}" "${TEMP_DIR}/rebased.tar.gz"
tar -xzf "${TEMP_DIR}/rebased.tar.gz" -C "${TEMP_DIR}" \
  idea-IC-261.25134.SNAPSHOT/product-info.json \
  idea-IC-261.25134.SNAPSHOT/build.txt \
  idea-IC-261.25134.SNAPSHOT/bin/idea64.vmoptions

download_file "${PLUGIN_SCRIPT_URL}" "${TEMP_DIR}/prepare-jetbrains-zh-plugin.sh"
HOME="${TEMP_DIR}/home" XDG_DATA_HOME="${TEMP_DIR}/data" \
  bash "${TEMP_DIR}/prepare-jetbrains-zh-plugin.sh" \
  --source "${PLUGIN_SOURCE_PATH}" \
  --ide "${TEMP_DIR}/idea-IC-261.25134.SNAPSHOT" \
  --output "${plugin_output_path}" >/dev/null

plugin_sha256="$(sha256sum "${plugin_output_path}" | cut -d ' ' -f 1)"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-zh-bin
_pkgname=rebased
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Standalone JetBrains-based Git client with bundled Chinese language pack'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
optdepends=('xdg-utils: open URLs from IDE')
provides=('rebased' 'rebased-zh')
conflicts=('rebased' 'rebased-bin')
options=('!strip')
source=(
  "\${_pkgname}-\${pkgver}-\${CARCH}.tar.gz::https://github.com/DetachHead/rebased/releases/download/\${pkgver}/rebased.tar.gz"
  "localization-zh.jar::https://raw.githubusercontent.com/duanluan/aur-packages/main/packages/rebased-zh-bin/assets/\${pkgver}/localization-zh.jar"
)
sha256sums=(
  '${asset_sha256}'
  '${plugin_sha256}'
)

package() {
  local app_dir="\${srcdir}/idea-IC-261.25134.SNAPSHOT"
  local install_root="\${pkgdir}/opt/\${_pkgname}"

  install -dm755 "\${install_root}"
  cp -a "\${app_dir}/." "\${install_root}/"
  install -Dm644 "\${srcdir}/localization-zh.jar" "\${install_root}/plugins/localization-zh/lib/localization-zh.jar"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/rebased" <<'SCRIPT'
#!/bin/sh
set -eu

plugin_src="/opt/rebased/plugins/localization-zh/lib/localization-zh.jar"
plugin_dst="\${XDG_DATA_HOME:-\${HOME}/.local/share}/detachhead/IdeaIC1.1/localization-zh.jar"

if [ -r "\${plugin_src}" ]; then
  mkdir -p "\$(dirname "\${plugin_dst}")"
  if [ ! -f "\${plugin_dst}" ] || ! cmp -s "\${plugin_src}" "\${plugin_dst}"; then
    cp "\${plugin_src}" "\${plugin_dst}"
  fi
fi

exec /opt/rebased/bin/idea "\$@"
SCRIPT

  install -Dm644 "\${install_root}/bin/idea.svg" "\${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  install -Dm644 "\${install_root}/bin/idea.png" "\${pkgdir}/usr/share/pixmaps/rebased.png"
  install -Dm644 "\${install_root}/LICENSE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.txt"
  install -Dm644 "\${install_root}/NOTICE.txt" "\${pkgdir}/usr/share/licenses/\${pkgname}/NOTICE.txt"

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/rebased.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Rebased
Comment=Standalone Git client based on IntelliJ platform
Exec=rebased %f
Icon=rebased
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-rebased
Categories=Development;IDE;VersionControl;
Keywords=git;vcs;jetbrains;
X-Rebased-Version=\${pkgver}
DESKTOP
}
EOF

(
  cd "${SCRIPT_DIR}"
  rm -f localization-zh.jar
  ln -s "assets/${pkgver}/localization-zh.jar" localization-zh.jar
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
