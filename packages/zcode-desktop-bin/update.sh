#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
VERSION_URL="${VERSION_URL:-https://zcode.z.ai/en}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://cdn-zcode.z.ai/zcode/electron/releases}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command rg
require_command sha256sum
require_command makepkg

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    --speed-limit 1024 \
    --speed-time 60 \
    "$@"
}

target_pkgver="${PKGVER:-}"

if [[ -n "${target_pkgver}" ]]; then
  pkgver="${target_pkgver}"
  x64_url="${RELEASE_BASE_URL}/${pkgver}/linux-x64/ZCode-${pkgver}-linux-x64.deb"
  arm64_url="${RELEASE_BASE_URL}/${pkgver}/linux-arm64/ZCode-${pkgver}-linux-arm64.deb"
  arm64_pkgver="${pkgver}"
else
  page="$(curl -fsSL "${VERSION_URL}")"
  x64_url="$(
    printf '%s\n' "${page}" |
      rg -o 'https://[^"'\'' ]+/ZCode-[0-9][0-9.]*-linux-x64[.]deb' |
      head -n1
  )"
  pkgver="$(printf '%s\n' "${x64_url}" | sed -n 's|.*/ZCode-\([0-9][0-9.]*\)-linux-x64[.]deb$|\1|p')"
  arm64_url="$(
    printf '%s\n' "${page}" |
      rg -o 'https://[^"'\'' ]+/ZCode-[0-9][0-9.]*-linux-arm64[.]deb' |
      head -n1
  )"
  arm64_pkgver="$(printf '%s\n' "${arm64_url}" | sed -n 's|.*/ZCode-\([0-9][0-9.]*\)-linux-arm64[.]deb$|\1|p')"
fi

if [[ -z "${x64_url}" || -z "${pkgver}" || -z "${arm64_url}" || "${arm64_pkgver}" != "${pkgver}" ]]; then
  printf 'failed to resolve latest ZCode Linux deb version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl_retry "${x64_url}" -o "${tmpdir}/ZCode-${pkgver}-linux-x64.deb" >/dev/null
curl_retry "${arm64_url}" -o "${tmpdir}/ZCode-${pkgver}-linux-arm64.deb" >/dev/null
x64_sha256="$(sha256sum "${tmpdir}/ZCode-${pkgver}-linux-x64.deb" | awk '{print $1}')"
arm64_sha256="$(sha256sum "${tmpdir}/ZCode-${pkgver}-linux-arm64.deb" | awk '{print $1}')"
x64_pkgbuild_url="${x64_url//${pkgver}/\$\{pkgver\}}"
arm64_pkgbuild_url="${arm64_url//${pkgver}/\$\{pkgver\}}"
x64_source_line="source_x86_64=(\"ZCode-\${pkgver}-linux-x64.deb::${x64_pkgbuild_url}\")"
arm64_source_line="source_aarch64=(\"ZCode-\${pkgver}-linux-arm64.deb::${arm64_pkgbuild_url}\")"

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s|^source_x86_64=.*|${x64_source_line}|" \
  -e "s|^source_aarch64=.*|${arm64_source_line}|" \
  -e "s|^sha256sums_x86_64=.*|sha256sums_x86_64=('${x64_sha256}')|" \
  -e "s|^sha256sums_aarch64=.*|sha256sums_aarch64=('${arm64_sha256}')|" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
