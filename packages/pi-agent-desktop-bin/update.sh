#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
LICENSE_PATH="${SCRIPT_DIR}/LICENSE"
REPO="abcwyc/pi-agent-desktop"

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

current_pkgver=""
current_pkgrel=""
current_sha256=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" "https://api.github.com/repos/${REPO}/releases/latest")"
tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

asset_name="Pi.Agent_${pkgver}_amd64.deb"
asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg name "${asset_name}" '.assets[] | select(.name == $name) | .browser_download_url' | head -n1)"

if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve release asset: %s\n' "${asset_name}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp pi-agent-desktop-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL --retry 5 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
license_sha256="$(sha256sum "${LICENSE_PATH}" | awk '{print $1}')"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256}" == "${asset_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=pi-agent-desktop-bin
_pkgname=pi-agent-desktop
_appname='Pi Agent'
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Desktop UI for browsing sessions and working with the pi coding agent (prebuilt binary)'
arch=('x86_64')
url='https://github.com/abcwyc/pi-agent-desktop'
license=('MIT')
depends=('gtk3' 'libayatana-appindicator' 'webkit2gtk-4.1')
provides=("\${_pkgname}")
conflicts=("\${_pkgname}")
options=('!strip')
source=("\${_appname// /_}_\${pkgver}_amd64.deb::https://github.com/abcwyc/pi-agent-desktop/releases/download/v\${pkgver}/Pi.Agent_\${pkgver}_amd64.deb"
        'LICENSE')
sha256sums=('${asset_sha256}'
            '${license_sha256}')

package() {
  local extract_dir="\${srcdir}/deb-extract"

  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"
  bsdtar -C "\${extract_dir}" -xf "\${srcdir}/\${_appname// /_}_\${pkgver}_amd64.deb"
  bsdtar -C "\${pkgdir}" -xf "\${extract_dir}/data.tar.gz"

  mv "\${pkgdir}/usr/bin/\${_pkgname}" \\
    "\${pkgdir}/usr/lib/\${_appname}/\${_pkgname}"
  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
export WEBKIT_DISABLE_DMABUF_RENDERER="\${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
exec '/usr/lib/Pi Agent/pi-agent-desktop' "\$@"
SCRIPT

  install -Dm644 "\${srcdir}/LICENSE" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
