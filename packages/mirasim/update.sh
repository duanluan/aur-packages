#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASES_URL="${RELEASES_URL:-https://cdn-assets.mirasim.ai/mirasim/releases}"
DOWNLOAD_PAGE_URL="${DOWNLOAD_PAGE_URL:-https://mirasim.ai/download}"
DEB_NAME_X86_64="Mirasim-linux-amd64.deb"
DEB_NAME_AARCH64="Mirasim-linux-arm64.deb"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command bsdtar
require_command rg
require_command awk
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
    --retry-max-time 180 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "$@"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# The CDN has no "latest" pointer, so the current stable version is read from
# the download page, which links every artifact under releases/v<version>/.
curl_retry --output "${tmpdir}/download.html" "${DOWNLOAD_PAGE_URL}" >/dev/null
pkgver="$(rg -o 'releases/v[0-9]+\.[0-9]+\.[0-9]+/' "${tmpdir}/download.html" \
  | sed -e 's#releases/v##' -e 's#/$##' \
  | sort -V \
  | tail -n 1)"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest Mirasim version\n' >&2
  exit 1
fi

pinned_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"

# Every upstream build gets its own 0.0.x number, so an unchanged version means
# no new download. A rebuilt artifact under the same version is not re-checked.
if [[ "${pinned_pkgver}" == "${pkgver}" ]]; then
  pinned_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  printf '%s-%s\n' "${pkgver}" "${pinned_pkgrel}"
  exit 0
fi

curl_retry --output "${tmpdir}/${DEB_NAME_X86_64}" \
  "${RELEASES_URL}/v${pkgver}/Mirasim-${pkgver}-linux-amd64.deb" >/dev/null
curl_retry --output "${tmpdir}/${DEB_NAME_AARCH64}" \
  "${RELEASES_URL}/v${pkgver}/Mirasim-${pkgver}-linux-arm64.deb" >/dev/null
x86_64_sha256="$(sha256sum "${tmpdir}/${DEB_NAME_X86_64}" | awk '{print $1}')"
aarch64_sha256="$(sha256sum "${tmpdir}/${DEB_NAME_AARCH64}" | awk '{print $1}')"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=\(/ {on=1} on && $2 ~ /^[0-9a-f]{64}$/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_aarch64_sha256="$(awk -F"'" '/^sha256sums_aarch64=\(/ {on=1} on && $2 ~ /^[0-9a-f]{64}$/ {print $2; exit}' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" &&
      "${current_aarch64_sha256}" == "${aarch64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" &&
        "${current_pkgrel}" =~ ^[0-9]+$ &&
        "${current_x86_64_sha256}" =~ ^[0-9a-f]{64}$ &&
        "${current_aarch64_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "/^sha256sums_x86_64=(/,/^)/ s/^[[:space:]]*'[0-9a-f]\\{64\\}'/  '${x86_64_sha256}'/" \
  -e "/^sha256sums_aarch64=(/,/^)/ s/^[[:space:]]*'[0-9a-f]\\{64\\}'/  '${aarch64_sha256}'/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
