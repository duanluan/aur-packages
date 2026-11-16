#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/duanluan/zcode-pro/releases/latest}"
RELEASE_LATEST_URL="${RELEASE_LATEST_URL:-https://github.com/duanluan/zcode-pro/releases/latest}"

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
    --retry-max-time 180 \
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

# releases/latest 是权威版本来源；API 被限流时退回解析跳转地址
if release_json="$(curl_retry "${curl_headers[@]}" "${RELEASE_API_URL}")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
else
  latest_headers="$(curl -fsSLI "${RELEASE_LATEST_URL}")"
  tag_name="$(printf '%s\n' "${latest_headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1)"
fi

pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "${tag_name}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

asset_name="zcode-pro-${pkgver}.tar.gz"
asset_url="https://github.com/duanluan/zcode-pro/releases/download/${tag_name}/${asset_name}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl_retry --output "${tmpdir}/${asset_name}" "${asset_url}" >/dev/null
source_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_sha256="$(awk -F"'" '$2 ~ /^[0-9a-f]{64}$/ { print $2; exit }' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256}" == "${source_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" &&
        "${current_pkgrel}" =~ ^[0-9]+$ &&
        "${current_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s|^sha256sums=.*|sha256sums=('${source_sha256}')|" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
