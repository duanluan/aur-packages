#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="xintaofei/codeg"

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
  printf '%s\n' "${headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1
}

current_pkgver=""
current_pkgrel=""
current_license_sha256=""
current_x86_64_sha256=""
current_aarch64_sha256=""
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

release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null)"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
else
  tag_name="$(latest_release_tag)"
fi
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

x86_64_asset="codeg-server-linux-x64.tar.gz"
aarch64_asset="codeg-server-linux-arm64.tar.gz"
if [[ -n "${release_json}" ]]; then
  x86_64_url="$(printf '%s\n' "${release_json}" | jq -r --arg name "${x86_64_asset}" '.assets[] | select(.name == $name) | .browser_download_url' | head -n1)"
  aarch64_url="$(printf '%s\n' "${release_json}" | jq -r --arg name "${aarch64_asset}" '.assets[] | select(.name == $name) | .browser_download_url' | head -n1)"
else
  x86_64_url="https://github.com/${REPO}/releases/download/${tag_name}/${x86_64_asset}"
  aarch64_url="https://github.com/${REPO}/releases/download/${tag_name}/${aarch64_asset}"
fi
license_url="https://raw.githubusercontent.com/${REPO}/${tag_name}/LICENSE"

if [[ -z "${x86_64_url}" || "${x86_64_url}" == "null" ]]; then
  printf 'failed to resolve release asset: %s\n' "${x86_64_asset}" >&2
  exit 1
fi

if [[ -z "${aarch64_url}" || "${aarch64_url}" == "null" ]]; then
  printf 'failed to resolve release asset: %s\n' "${aarch64_asset}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp codeg-server-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL --retry 5 --retry-all-errors "${x86_64_url}" -o "${tmpdir}/${x86_64_asset}" >/dev/null 2>&1
curl -fL --retry 5 --retry-all-errors "${aarch64_url}" -o "${tmpdir}/${aarch64_asset}" >/dev/null 2>&1
curl -fL --retry 5 --retry-all-errors "${license_url}" -o "${tmpdir}/LICENSE" >/dev/null 2>&1

x86_64_sha256="$(sha256sum "${tmpdir}/${x86_64_asset}" | awk '{print $1}')"
aarch64_sha256="$(sha256sum "${tmpdir}/${aarch64_asset}" | awk '{print $1}')"
license_sha256="$(sha256sum "${tmpdir}/LICENSE" | awk '{print $1}')"

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

pkgname=codeg-server-bin
_pkgname=codeg-server
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Standalone server of Codeg, a collaborative multi-agent AI coding workspace (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/xintaofei/codeg'
license=('Apache-2.0')
depends=(
  'gcc-libs'
  'glibc'
  'openssl'
  'xz'
)
provides=('codeg-server')
conflicts=('codeg-server')
options=('!strip')
source=("LICENSE-\${pkgver}::https://raw.githubusercontent.com/xintaofei/codeg/v\${pkgver}/LICENSE")
source_x86_64=("codeg-server-linux-x64.tar.gz::https://github.com/xintaofei/codeg/releases/download/v\${pkgver}/codeg-server-linux-x64.tar.gz")
source_aarch64=("codeg-server-linux-arm64.tar.gz::https://github.com/xintaofei/codeg/releases/download/v\${pkgver}/codeg-server-linux-arm64.tar.gz")
sha256sums=('${license_sha256}')
sha256sums_x86_64=('${x86_64_sha256}')
sha256sums_aarch64=('${aarch64_sha256}')

package() {
  local tar_root

  case "\${CARCH}" in
    x86_64) tar_root='codeg-server-linux-x64' ;;
    aarch64) tar_root='codeg-server-linux-arm64' ;;
    *)
      printf 'unsupported architecture: %s\\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  install -dm755 "\${pkgdir}/usr/lib/\${_pkgname}"
  cp -a "\${srcdir}/\${tar_root}/." "\${pkgdir}/usr/lib/\${_pkgname}/"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
cd /usr/lib/codeg-server || exit 1
exec ./codeg-server "\$@"
SCRIPT

  install -Dm644 "\${srcdir}/LICENSE-\${pkgver}" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
