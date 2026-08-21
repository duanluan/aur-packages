#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
CONFIG_URL="${CONFIG_URL:-https://mastergo.com/api/v1/config}"

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
    --retry-max-time 180 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "$@"
}

config_json="$(curl_retry "${CONFIG_URL}")"
pkgver="$(printf '%s\n' "${config_json}" | jq -r '.data | fromjson | .electronMacM1')"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest MasterGo macOS version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

source_url="https://static.mastergo.com/plugins/desktop/macos-arm/MasterGo-${pkgver}.dmg"
curl_retry --output "${tmpdir}/MasterGo-${pkgver}-mac-arm64.dmg" "${source_url}" >/dev/null
source_sha256="$(sha256sum "${tmpdir}/MasterGo-${pkgver}-mac-arm64.dmg" | awk '{print $1}')"

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "0,/^[[:space:]]*'[0-9a-f]\\{64\\}'/{s/^[[:space:]]*'[0-9a-f]\\{64\\}'/  '${source_sha256}'/}" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
