#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASES_URL="${RELEASES_URL:-https://qoder-app.oss-cn-beijing.aliyuncs.com/qoder-app/releases}"
DEB_NAME_X86_64="Qoder-CN-linux-amd64.deb"
DEB_NAME_AARCH64="Qoder-CN-linux-arm64.deb"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command bsdtar
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

# The "latest" URL hides its version number, so read the deb control block
# through a small range request instead of downloading the full archive.
# bsdtar reports the data member as truncated afterwards; the control member
# itself is complete and that is all we need.
curl_retry --range 0-262143 --output "${tmpdir}/head.deb" \
  "${RELEASES_URL}/latest/${DEB_NAME_X86_64}" >/dev/null
bsdtar -xOf "${tmpdir}/head.deb" control.tar.xz \
  > "${tmpdir}/control.tar.xz" 2>/dev/null || true
pkgver="$(bsdtar -xOf "${tmpdir}/control.tar.xz" ./control 2>/dev/null \
  | awk -F': ' '/^Version:/ {print $2; exit}')"
# drop the deb epoch prefix (e.g. 1:0.4.4) and map dashes to dots for pkgver
pkgver="${pkgver#*:}"
pkgver="${pkgver//-/.}"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest Qoder CN deb version\n' >&2
  exit 1
fi

pinned_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"

# Same upstream version: skip the 200+ MB downloads unless upstream rebuilt
# either architecture, which is detected by comparing the pinned and latest
# ETags of both debs.
if [[ "${pinned_pkgver}" == "${pkgver}" ]]; then
  etag_of() {
    curl_retry --head "$1" \
      | awk 'tolower($1)=="etag:" {gsub(/"/, "", $2); print $2; exit}'
  }
  pinned_etag="$(etag_of "${RELEASES_URL}/${pkgver}/${DEB_NAME_X86_64}")"
  latest_etag="$(etag_of "${RELEASES_URL}/latest/${DEB_NAME_X86_64}")"
  pinned_arm_etag="$(etag_of "${RELEASES_URL}/${pkgver}/${DEB_NAME_AARCH64}")"
  latest_arm_etag="$(etag_of "${RELEASES_URL}/latest/${DEB_NAME_AARCH64}")"
  if [[ -n "${pinned_etag}" && "${pinned_etag}" == "${latest_etag}" &&
        -n "${pinned_arm_etag}" && "${pinned_arm_etag}" == "${latest_arm_etag}" ]]; then
    pinned_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
    printf '%s-%s\n' "${pkgver}" "${pinned_pkgrel}"
    exit 0
  fi
fi

curl_retry --output "${tmpdir}/${DEB_NAME_X86_64}" \
  "${RELEASES_URL}/${pkgver}/${DEB_NAME_X86_64}" >/dev/null
curl_retry --output "${tmpdir}/${DEB_NAME_AARCH64}" \
  "${RELEASES_URL}/${pkgver}/${DEB_NAME_AARCH64}" >/dev/null
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
