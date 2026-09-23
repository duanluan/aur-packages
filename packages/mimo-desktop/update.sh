#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
MANIFEST_URL="${MANIFEST_URL:-https://mimocode-cdn.xiaomimimo.com/mimocode/mimodesktop/manifest.json}"
DEB_URL_PREFIX='https://mimocode-cdn.xiaomimimo.com/mimocode/mimodesktop'

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

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-max-time 300 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    --speed-limit 1024 \
    --speed-time 60 \
    "$@"
}

manifest="$(curl_retry "${MANIFEST_URL}")"

pkgver="$(printf '%s' "${manifest}" | jq -r '.platforms["linux-x64"].version // empty')"
deb_url="$(printf '%s' "${manifest}" | jq -r '.platforms["linux-x64"].debUrl // empty')"
manifest_sha256="$(printf '%s' "${manifest}" | jq -r '.platforms["linux-x64"].debSha256hash // empty')"

if [[ -z "${pkgver}" || -z "${deb_url}" || -z "${manifest_sha256}" ]]; then
  printf 'failed to resolve latest Xiaomi MiMo Linux release from manifest\n' >&2
  exit 1
fi

if [[ "${deb_url}" != "${DEB_URL_PREFIX}/XiaomiMiMo-${pkgver}-x64.deb" ]]; then
  printf 'unexpected deb url for %s: %s\n' "${pkgver}" "${deb_url}" >&2
  exit 1
fi

current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
current_sha256="$(sed -n "s/^sha256sums_x86_64=('\([0-9a-f]\{64\}\)')/\1/p" "${PKGBUILD_PATH}" | head -n1)"

if [[ "${pkgver}" == "${current_pkgver}" && "${manifest_sha256}" == "${current_sha256}" ]]; then
  printf 'up to date: %s\n' "${pkgver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

deb_file="XiaomiMiMo-${pkgver}-x64.deb"
curl_retry --output "${tmpdir}/${deb_file}" "${deb_url}" >/dev/null
deb_sha256="$(sha256sum "${tmpdir}/${deb_file}" | awk '{print $1}')"

if [[ "${deb_sha256}" != "${manifest_sha256}" ]]; then
  printf 'sha256 mismatch between manifest and downloaded deb: %s\n' "${deb_url}" >&2
  exit 1
fi

if [[ "${pkgver}" != "${current_pkgver}" ]]; then
  pkgrel=1
else
  pkgrel=$((current_pkgrel + 1))
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s|^source_x86_64=.*|source_x86_64=(\"XiaomiMiMo-\${pkgver}-x64.deb::${deb_url}\")|" \
  -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${deb_sha256}')|" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
