#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO='op7418/CodePilot'

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

latest_release_tag() {
  local headers

  headers="$(curl -fsSLI "https://github.com/${REPO}/releases/latest")"
  printf '%s\n' "${headers}" | sed -nE \
    's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1
}

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

release_json=''
if release_json="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null)"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
else
  tag_name="$(latest_release_tag)"
fi
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == 'null' || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

x86_64_asset="CodePilot-${pkgver}-amd64.deb"
aarch64_asset="CodePilot-${pkgver}-arm64.deb"
if [[ -n "${release_json}" ]]; then
  x86_64_url="$(asset_field "${x86_64_asset}" browser_download_url)"
  aarch64_url="$(asset_field "${aarch64_asset}" browser_download_url)"
  x86_64_digest="$(asset_field "${x86_64_asset}" digest)"
  aarch64_digest="$(asset_field "${aarch64_asset}" digest)"
else
  x86_64_url="https://github.com/${REPO}/releases/download/${tag_name}/${x86_64_asset}"
  aarch64_url="https://github.com/${REPO}/releases/download/${tag_name}/${aarch64_asset}"
  x86_64_digest=''
  aarch64_digest=''
fi
license_url="https://raw.githubusercontent.com/${REPO}/${tag_name}/LICENSE"

if [[ -z "${x86_64_url}" ]]; then
  printf 'failed to resolve release asset: %s\n' "${x86_64_asset}" >&2
  exit 1
fi

if [[ -z "${aarch64_url}" ]]; then
  printf 'failed to resolve release asset: %s\n' "${aarch64_asset}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp codepilot-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

license_sha256="$(download_sha256 "${license_url}" "${tmpdir}/LICENSE")"
x86_64_sha256="${x86_64_digest#sha256:}"
aarch64_sha256="${aarch64_digest#sha256:}"

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

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=codepilot-bin
_pkgname=codepilot
_appname=CodePilot
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Multi-model AI agent desktop client (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/op7418/CodePilot'
license=('BUSL-1.1')
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
optdepends=('org.freedesktop.secrets: secret storage backend')
provides=("\${_pkgname}=\${pkgver}")
conflicts=("\${_pkgname}" 'codepilot-appimage')
options=('!strip')
source=("LICENSE-\${pkgver}::https://raw.githubusercontent.com/op7418/CodePilot/v\${pkgver}/LICENSE")
source_x86_64=("\${_appname}-\${pkgver}-amd64.deb::https://github.com/op7418/CodePilot/releases/download/v\${pkgver}/\${_appname}-\${pkgver}-amd64.deb")
source_aarch64=("\${_appname}-\${pkgver}-arm64.deb::https://github.com/op7418/CodePilot/releases/download/v\${pkgver}/\${_appname}-\${pkgver}-arm64.deb")
noextract=("\${_appname}-\${pkgver}-amd64.deb" "\${_appname}-\${pkgver}-arm64.deb")
sha256sums=('${license_sha256}')
sha256sums_x86_64=('${x86_64_sha256}')
sha256sums_aarch64=('${aarch64_sha256}')

package() {
  local deb_arch
  local extract_dir="\${srcdir}/deb-extract-\${CARCH}"
  local data_archives

  case "\${CARCH}" in
    x86_64) deb_arch='amd64' ;;
    aarch64) deb_arch='arm64' ;;
    *)
      printf 'unsupported architecture: %s\\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"
  bsdtar -C "\${extract_dir}" -xf \\
    "\${srcdir}/\${_appname}-\${pkgver}-\${deb_arch}.deb"

  data_archives=("\${extract_dir}"/data.tar.*)
  if (( \${#data_archives[@]} != 1 )) || [[ ! -f "\${data_archives[0]}" ]]; then
    printf 'unable to locate the Debian data archive\\n' >&2
    return 1
  fi
  bsdtar -C "\${pkgdir}" -xf "\${data_archives[0]}"

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s "/opt/\${_appname}/\${_pkgname}" \\
    "\${pkgdir}/usr/bin/\${_pkgname}"

  chmod 0755 "\${pkgdir}/opt/\${_appname}/chrome-sandbox"
  install -Dm644 "\${srcdir}/LICENSE-\${pkgver}" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
