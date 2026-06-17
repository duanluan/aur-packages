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

config_json="$(curl -fsSL "${CONFIG_URL}")"
pkgver="$(printf '%s\n' "${config_json}" | jq -r '.data | fromjson | .electronMacM1')"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest MasterGo macOS version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

source_url="https://static.mastergo.com/plugins/desktop/macos-arm/MasterGo-${pkgver}.dmg"
curl -fL "${source_url}" -o "${tmpdir}/MasterGo-${pkgver}-mac-arm64.dmg" >/dev/null 2>&1
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
