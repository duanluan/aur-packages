#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO='ayuayue/PiDeck'

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
require_command mktemp
require_command sha256sum

asset_field() {
  local asset_name="$1"
  local field="$2"

  printf '%s\n' "${release_json}" | jq -r \
    --arg name "${asset_name}" --arg field "${field}" \
    '.assets[] | select(.name == $name) | .[$field] // empty' | head -n1
}

download_sha256() {
  local url="$1"
  local output="$2"

  curl -fL --retry 5 --retry-all-errors "${url}" -o "${output}" >/dev/null 2>&1
  sha256sum "${output}" | awk '{print $1}'
}

current_pkgver=''
current_pkgrel=''
current_license_sha256=''
current_x86_64_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_license_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/${REPO}/releases/latest")"
tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == 'null' || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

# 0.9.0 起上游 deb 资产按 electron-builder artifactName 模板命名为
# ${productName}_${version}_${arch}.deb（PiDeck_0.9.1_amd64.deb），
# 早期版本是 pi-desktop_${version}_amd64.deb
asset_name="PiDeck_${pkgver}_amd64.deb"
asset_url="$(asset_field "${asset_name}" browser_download_url)"
asset_digest="$(asset_field "${asset_name}" digest)"
if [[ -z "${asset_url}" ]]; then
  printf 'failed to resolve release asset: %s\n' "${asset_name}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp pideck-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

license_sha256="$(sha256sum "${SCRIPT_DIR}/LICENSE" | awk '{print $1}')"
x86_64_sha256="${asset_digest#sha256:}"

if [[ ! "${x86_64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  x86_64_sha256="$(download_sha256 \
    "${asset_url}" "${tmpdir}/${asset_name}")"
fi

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_license_sha256}" == "${license_sha256}" &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=pideck-bin
_appname=PiDeck
_binname=pideck
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Desktop workbench for managing local AI coding agent sessions (prebuilt binary)'
arch=('x86_64')
url='https://github.com/ayuayue/PiDeck'
license=('MIT')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'cairo'
  'dbus'
  'expat'
  'glib2'
  'glibc'
  'gtk3'
  'hicolor-icon-theme'
  'libcups'
  'libgcc'
  'libnotify'
  'libsecret'
  'libstdc++'
  'libx11'
  'libxcb'
  'libxcomposite'
  'libxdamage'
  'libxext'
  'libxfixes'
  'libxkbcommon'
  'libxrandr'
  'libxss'
  'libxtst'
  'mesa'
  'nspr'
  'nss'
  'pango'
  'systemd-libs'
  'util-linux-libs'
  'xdg-utils'
)
optdepends=(
  'git: Git integration'
  'libappindicator: system tray support'
  'org.freedesktop.secrets: secret storage backend'
)
provides=("pideck=\${pkgver}" "pi-desktop=\${pkgver}")
conflicts=('pideck' 'pi-desktop')
options=('!strip')
source=('LICENSE')
source_x86_64=("\${_appname}_\${pkgver}_amd64.deb::https://github.com/ayuayue/PiDeck/releases/download/v\${pkgver}/\${_appname}_\${pkgver}_amd64.deb")
noextract=("\${_appname}_\${pkgver}_amd64.deb")
sha256sums=('${license_sha256}')
sha256sums_x86_64=('${x86_64_sha256}')

package() {
  local extract_dir="\${srcdir}/deb-extract"
  local data_archives

  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"
  bsdtar -C "\${extract_dir}" -xf "\${srcdir}/\${_appname}_\${pkgver}_amd64.deb"

  data_archives=("\${extract_dir}"/data.tar.*)
  if (( \${#data_archives[@]} != 1 )) || [[ ! -f "\${data_archives[0]}" ]]; then
    printf 'unable to locate the Debian data archive\n' >&2
    return 1
  fi
  bsdtar -C "\${pkgdir}" -xf "\${data_archives[0]}"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${_appname}/\${_binname}" "\${pkgdir}/usr/bin/\${_binname}"
  # 保留旧命令名 pi-desktop，老用户脚本不断档
  ln -s "\${_binname}" "\${pkgdir}/usr/bin/pi-desktop"

  chmod 0755 "\${pkgdir}/opt/\${_appname}/chrome-sandbox"
  install -Dm644 "\${srcdir}/LICENSE" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
