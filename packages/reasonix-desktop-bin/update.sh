#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/esengine/DeepSeek-Reasonix/releases?per_page=10}"
ASSET_NAME_X86_64="ReasonixStudio-linux-amd64.deb"
ASSET_NAME_AARCH64="ReasonixStudio-linux-arm64.deb"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
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
    --retry-max-time 300 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "$@"
}

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl_retry "${curl_headers[@]}" "${RELEASE_API_URL}")"

# Upstream ships the desktop app as Reasonix Studio on the "studio-v" tag line;
# the older "desktop-v" line stopped at 1.39.11 and is not followed any more.
#
# Upstream stopped maintaining the project on 2026-11-12 with 2.61.0 as the
# final release, so this script always resolves the same version and normally
# changes nothing. It is kept out of the daily run on purpose (see the note in
# the repository README) and exists so a successor fork can be picked up by
# repointing RELEASE_API_URL and the asset names.
studio_release="$(printf '%s\n' "${release_json}" \
  | jq '[.[] | select(.tag_name | startswith("studio-v"))][0]')"
tag_name="$(printf '%s\n' "${studio_release}" | jq -r '.tag_name')"
pkgver="${tag_name#studio-v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest studio release tag\n' >&2
  exit 1
fi

asset_url_of() {
  printf '%s\n' "${studio_release}" \
    | jq -r --arg name "$1" '[.assets[] | select(.name == $name)][0].browser_download_url // empty'
}

asset_url_x86_64="$(asset_url_of "${ASSET_NAME_X86_64}")"
asset_url_aarch64="$(asset_url_of "${ASSET_NAME_AARCH64}")"

if [[ -z "${asset_url_x86_64}" || -z "${asset_url_aarch64}" ]]; then
  printf 'failed to resolve studio deb assets for %s\n' "${pkgver}" >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp reasonix-desktop-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

curl_retry --output "${tmpdir}/${ASSET_NAME_X86_64}" "${asset_url_x86_64}" >/dev/null
curl_retry --output "${tmpdir}/${ASSET_NAME_AARCH64}" "${asset_url_aarch64}" >/dev/null
x86_64_sha256="$(sha256sum "${tmpdir}/${ASSET_NAME_X86_64}" | awk '{print $1}')"
aarch64_sha256="$(sha256sum "${tmpdir}/${ASSET_NAME_AARCH64}" | awk '{print $1}')"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=\(/ {on=1} on && $2 ~ /^[0-9a-f]{64}$/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_aarch64_sha256="$(awk -F"'" '/^sha256sums_aarch64=\(/ {on=1} on && $2 ~ /^[0-9a-f]{64}$/ {print $2; exit}' "${PKGBUILD_PATH}")"

# An unchanged tag with unchanged checksums means the daily run has nothing to
# do. A release rebuilt under the same tag bumps pkgrel instead of resetting it.
if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" &&
      "${current_aarch64_sha256}" == "${aarch64_sha256}" ]]; then
  printf '%s-%s\n' "${pkgver}" "${current_pkgrel}"
  exit 0
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
