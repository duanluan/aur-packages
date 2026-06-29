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
current_idea_ver=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_source_line="$(sed -n 's/^source=(.*$/&/p' "${PKGBUILD_PATH}" | head -n1)"
  current_idea_ver="$(sed -n 's/^_idea_ver=//p' "${PKGBUILD_PATH}" | head -n1)"
fi

release_json="$(curl -fsSL "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
asset_name="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "rebased.tar.gz")][0].name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "rebased.tar.gz")][0].browser_download_url')"
asset_digest="$(printf '%s\n' "${release_json}" | jq -r '[.assets[] | select(.name == "rebased.tar.gz")][0].digest')"
pkgbuild_asset_url="${asset_url/\/download\/${pkgver}\//\/download\/\$\{pkgver\}\/}"
source_line="source=(\"\${_pkgname}-\${pkgver}.tar.gz::${pkgbuild_asset_url}\")"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve source tarball asset\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

if [[ -z "${asset_digest}" || "${asset_digest}" == "null" ]]; then
  curl -fL "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
else
  asset_sha256="${asset_digest#sha256:}"
fi

idea_redirect_url="https://download.jetbrains.com/product?code=IU&platform=linux"
idea_final_url="$(curl -sIL -o /dev/null -w '%{url_effective}' "${idea_redirect_url}")"
if [[ -z "${idea_final_url}" ]]; then
  printf 'failed to resolve IDEA download URL\n' >&2
  exit 1
fi

idea_ver="$(printf '%s\n' "${idea_final_url}" | sed -n 's/.*\/\(ideaIU\|idea\)-\([0-9.]\+\)\.tar\.gz$/\2/p')"
if [[ -z "${idea_ver}" ]]; then
  printf 'failed to extract IDEA version from URL: %s\n' "${idea_final_url}" >&2
  exit 1
fi

curl -fL "${idea_final_url}" -o "${tmpdir}/idea.tar.gz" >/dev/null 2>&1
idea_sha256="$(sha256sum "${tmpdir}/idea.tar.gz" | awk '{print $1}')"

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
# Contributor: seiuneko <chfsefefgesfen foxmail com>

pkgbase=rebased-bin
pkgname=(rebased-bin rebased-lang-pack-zh rebased-lang-pack-ja rebased-lang-pack-ko)
_pkgname=rebased
pkgver=${pkgver}
pkgrel=1
pkgdesc='Standalone JetBrains-based Git client (prebuilt binary)'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
_idea_ver=${idea_ver}
options=('!strip')
source=("\${_pkgname}-\${pkgver}.tar.gz::${pkgbuild_asset_url}"
        "ideaIU-\${_idea_ver}.tar.gz::https://download.jetbrains.com/idea/ideaIU-\${_idea_ver}.tar.gz")
sha256sums=('${asset_sha256}'
            '${idea_sha256}')
noextract=("ideaIU-\${_idea_ver}.tar.gz")

_idea_dir=''

prepare() {
  bsdtar -xf "\${srcdir}/ideaIU-\${_idea_ver}.tar.gz" \\
    --strip-components=2 \\
    "*/localization-zh" \\
    "*/localization-ja" \\
    "*/localization-ko"
}

package_rebased-bin() {
  optdepends=('xdg-utils: open URLs from the IDE'
               'rebased-lang-pack-zh: Chinese language pack'
               'rebased-lang-pack-ja: Japanese language pack'
               'rebased-lang-pack-ko: Korean language pack')
  provides=('rebased')
  conflicts=('rebased')

  source_root=""

  for candidate in "\${srcdir}"/idea-IC-* "\${srcdir}"/ideaIC-* "\${srcdir}"/rebased* "\${srcdir}"/Rebased*; do
    if [[ -d "\${candidate}" ]]; then
      source_root="\${candidate}"
      break
    fi
  done

  if [[ -z "\${source_root}" ]]; then
    printf 'failed to locate extracted source tree\n' >&2
    return 1
  fi

  install -dm755 "\${pkgdir}/opt/\${_pkgname}"
  cp -a "\${source_root}/." "\${pkgdir}/opt/\${_pkgname}/"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${_pkgname}/bin/idea" "\${pkgdir}/usr/bin/rebased"

  install -Dm644 "\${source_root}/bin/idea.svg" "\${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  install -Dm644 "\${source_root}/bin/idea.png" "\${pkgdir}/usr/share/pixmaps/rebased.png"
  install -Dm644 "\${source_root}/LICENSE.txt" "\${pkgdir}/usr/share/licenses/\${_pkgname}/LICENSE.txt"
  install -Dm644 "\${source_root}/NOTICE.txt" "\${pkgdir}/usr/share/licenses/\${_pkgname}/NOTICE.txt"

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

_install_lang-pack() {
  local lang="\$1"

  install -dm755 "\${pkgdir}/opt/\${_pkgname}/third-party-plugins"
  cp -a "\${srcdir}/localization-\${lang}" "\${pkgdir}/opt/\${_pkgname}/third-party-plugins/"
}

package_rebased-lang-pack-zh() {
  pkgdesc="Chinese language pack for Rebased"
  arch=('any')
  url="https://www.jetbrains.com/idea/"
  license=('custom:commercial')
  depends=("rebased-bin=\${pkgver}")
  _install_lang-pack zh
}

package_rebased-lang-pack-ja() {
  pkgdesc="Japanese language pack for Rebased"
  arch=('any')
  url="https://www.jetbrains.com/idea/"
  license=('custom:commercial')
  depends=("rebased-bin=\${pkgver}")
  _install_lang-pack ja
}

package_rebased-lang-pack-ko() {
  pkgdesc="Korean language pack for Rebased"
  arch=('any')
  url="https://www.jetbrains.com/idea/"
  license=('custom:commercial')
  depends=("rebased-bin=\${pkgver}")
  _install_lang-pack ko
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"