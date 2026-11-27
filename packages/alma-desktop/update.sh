#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
FEED_X86_64="${FEED_X86_64:-https://updates.alma.now/latest-linux.yml}"
FEED_AARCH64="${FEED_AARCH64:-https://updates.alma.now/latest-linux-arm64.yml}"
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://github.com/yetone/alma-releases/releases/download}"
DEB_X86_64="${DEB_X86_64:-alma-%s-linux-amd64.deb}"
DEB_AARCH64="${DEB_AARCH64:-alma-%s-linux-arm64.deb}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command makepkg
require_command mktemp
require_command sha256sum

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-max-time 600 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    --speed-limit 1024 \
    --speed-time 60 \
    "$@"
}

# The update feed lists every Linux asset with its size and sha512, so a
# version check costs two small YAML downloads instead of the 500 MB of debs.
feed_version() {
  curl_retry "$1" | sed -n 's/^version:[[:space:]]*//p' | head -n1
}

feed_sha512() {
  local feed="$1"
  local asset="$2"

  curl_retry "${feed}" | awk -v asset="${asset}" '
    $1 == "-" && $2 == "url:" { current = $3 }
    current == asset && $1 == "sha512:" { print $2; exit }
  '
}

current_pkgver=''
current_pkgrel=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

pkgver="$(feed_version "${FEED_X86_64}")"
arm64_pkgver="$(feed_version "${FEED_AARCH64}")"

if [[ -z "${pkgver}" || -z "${arm64_pkgver}" ]]; then
  printf 'failed to resolve the latest version from the update feed\n' >&2
  exit 1
fi
if [[ "${pkgver}" != "${arm64_pkgver}" ]]; then
  printf 'architecture version mismatch: x86_64=%s aarch64=%s\n' "${pkgver}" "${arm64_pkgver}" >&2
  exit 1
fi

x86_64_asset="$(printf "${DEB_X86_64}" "${pkgver}")"
aarch64_asset="$(printf "${DEB_AARCH64}" "${pkgver}")"
x86_64_upstream_sha512="$(feed_sha512 "${FEED_X86_64}" "${x86_64_asset}")"
aarch64_upstream_sha512="$(feed_sha512 "${FEED_AARCH64}" "${aarch64_asset}")"

if [[ -z "${x86_64_upstream_sha512}" || -z "${aarch64_upstream_sha512}" ]]; then
  printf 'failed to resolve deb digests from the update feed\n' >&2
  exit 1
fi

current_x86_64_sha512="$(sed -n 's/^# upstream sha512 x86_64=//p' "${PKGBUILD_PATH}" | head -n1)"
current_aarch64_sha512="$(sed -n 's/^# upstream sha512 aarch64=//p' "${PKGBUILD_PATH}" | head -n1)"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_x86_64_sha512}" == "${x86_64_upstream_sha512}" &&
      "${current_aarch64_sha512}" == "${aarch64_upstream_sha512}" ]]; then
  printf '%s-%s\n' "${pkgver}" "${current_pkgrel}"
  exit 0
fi

tmpdir="$(mktemp -d -p /var/tmp alma-desktop.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

download_sha256() {
  local asset="$1"
  local output="${tmpdir}/${asset}"

  curl_retry --output "${output}" "${DOWNLOAD_BASE}/v${pkgver}/${asset}" >/dev/null
  sha256sum "${output}" | awk '{print $1}'
}

x86_64_sha256="$(download_sha256 "${x86_64_asset}")"
aarch64_sha256="$(download_sha256 "${aarch64_asset}")"

if [[ ! "${x86_64_sha256}" =~ ^[0-9a-f]{64}$ || ! "${aarch64_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  printf 'failed to compute deb checksums\n' >&2
  exit 1
fi

current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=\(/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_aarch64_sha256="$(awk -F"'" '/^sha256sums_aarch64=\(/ {print $2; exit}' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" &&
      "${current_aarch64_sha256}" == "${aarch64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  # 同版本重新构建：上游替换了资产，提升 pkgrel
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s|^# upstream sha512 x86_64=.*|# upstream sha512 x86_64=${x86_64_upstream_sha512}|" \
  -e "s|^# upstream sha512 aarch64=.*|# upstream sha512 aarch64=${aarch64_upstream_sha512}|" \
  -e "/^sha256sums_x86_64=(/ s/'[0-9a-f]\{64\}'/'${x86_64_sha256}'/" \
  -e "/^sha256sums_aarch64=(/ s/'[0-9a-f]\{64\}'/'${aarch64_sha256}'/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
