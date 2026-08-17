#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
LICENSE_PATH="${SCRIPT_DIR}/LICENSE"
REPO='am-will/gooey-pi'

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command base64
require_command curl
require_command install
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
current_aarch64_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_license_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_aarch64_sha256="$(awk -F"'" '/^sha256sums_aarch64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
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

if [[ -z "${tag_name}" || "${tag_name}" == 'null' || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

x86_64_asset="GooeyPi-${pkgver}-linux-x64.pacman"
aarch64_asset="GooeyPi-${pkgver}-linux-aarch64.pacman"
x86_64_url="$(asset_field "${x86_64_asset}" browser_download_url)"
aarch64_url="$(asset_field "${aarch64_asset}" browser_download_url)"
x86_64_digest="$(asset_field "${x86_64_asset}" digest)"
aarch64_digest="$(asset_field "${aarch64_asset}" digest)"

if [[ -z "${x86_64_url}" ]]; then
  printf 'failed to resolve release asset: %s\n' "${x86_64_asset}" >&2
  exit 1
fi

if [[ -z "${aarch64_url}" ]]; then
  printf 'failed to resolve release asset: %s\n' "${aarch64_asset}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp gooeypi-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

license_json="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/${REPO}/contents/LICENSE?ref=${tag_name}")"
printf '%s\n' "${license_json}" | jq -r '.content' | base64 --decode > "${tmpdir}/LICENSE"
license_sha256="$(sha256sum "${tmpdir}/LICENSE" | awk '{print $1}')"
x86_64_sha256="${x86_64_digest#sha256:}"
aarch64_sha256="${aarch64_digest#sha256:}"

if [[ ! "${license_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  printf 'failed to resolve upstream license checksum\n' >&2
  exit 1
fi

if [[ ! "${x86_64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  x86_64_sha256="$(download_sha256 \
    "${x86_64_url}" "${tmpdir}/${x86_64_asset}")"
fi

if [[ ! "${aarch64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  aarch64_sha256="$(download_sha256 \
    "${aarch64_url}" "${tmpdir}/${aarch64_asset}")"
fi

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_license_sha256}" == "${license_sha256}" &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" &&
      "${current_aarch64_sha256}" == "${aarch64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

install -Dm644 "${tmpdir}/LICENSE" "${LICENSE_PATH}"

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=gooeypi-bin
_pkgname=gooeypi
_appname=GooeyPi
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Desktop workspace for Pi, OMP, and Prime Agent (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/am-will/gooey-pi'
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
  'mesa'
  'nspr'
  'nss'
  'pango'
  'systemd-libs'
  'util-linux-libs'
  'xdg-utils'
)
optdepends=(
  'org.freedesktop.secrets: secure storage backend'
  'pipewire: screen sharing under Wayland'
  'kde-cli-tools: file deletion support on KDE'
  'trash-cli: file deletion fallback'
)
provides=("\${_pkgname}=\${pkgver}")
conflicts=("\${_pkgname}")
options=('!strip')
source=('LICENSE')
source_x86_64=("\${_appname}-\${pkgver}-linux-x64.pacman::https://github.com/am-will/gooey-pi/releases/download/v\${pkgver}/\${_appname}-\${pkgver}-linux-x64.pacman")
source_aarch64=("\${_appname}-\${pkgver}-linux-aarch64.pacman::https://github.com/am-will/gooey-pi/releases/download/v\${pkgver}/\${_appname}-\${pkgver}-linux-aarch64.pacman")
noextract=("\${_appname}-\${pkgver}-linux-x64.pacman" "\${_appname}-\${pkgver}-linux-aarch64.pacman")
sha256sums=('${license_sha256}')
sha256sums_x86_64=('${x86_64_sha256}')
sha256sums_aarch64=('${aarch64_sha256}')

package() {
  local upstream_arch
  local archive

  case "\${CARCH}" in
    x86_64) upstream_arch='x64' ;;
    aarch64) upstream_arch='aarch64' ;;
    *)
      printf 'unsupported architecture: %s\\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  archive="\${srcdir}/\${_appname}-\${pkgver}-linux-\${upstream_arch}.pacman"
  bsdtar -C "\${pkgdir}" \\
    --exclude='.BUILDINFO' \\
    --exclude='.INSTALL' \\
    --exclude='.MTREE' \\
    --exclude='.PKGINFO' \\
    -xf "\${archive}"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${_appname}/\${_pkgname}" \\
    "\${pkgdir}/usr/bin/\${_pkgname}"

  chmod 0755 "\${pkgdir}/opt/\${_appname}/chrome-sandbox"
  install -Dm644 "\${srcdir}/LICENSE" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
