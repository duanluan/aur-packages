#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
VERSION_URL="${VERSION_URL:-https://zcode.z.ai/en}"

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

page="$(curl -fsSL "${VERSION_URL}")"
source_url="$(
  printf '%s\n' "${page}" |
    rg -o 'https://[^"'\'' ]+/ZCode-[0-9][0-9.]*-mac-arm64[.]dmg' |
    head -n1
)"
pkgver="$(printf '%s\n' "${source_url}" | sed -n 's|.*/ZCode-\([0-9][0-9.]*\)-mac-arm64[.]dmg$|\1|p')"

if [[ -z "${source_url}" || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest ZCode mac arm64 version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL "${source_url}" -o "${tmpdir}/ZCode-${pkgver}-mac-arm64.dmg" >/dev/null 2>&1
source_sha256="$(sha256sum "${tmpdir}/ZCode-${pkgver}-mac-arm64.dmg" | awk '{print $1}')"
pkgbuild_source_url="${source_url//${pkgver}/\$\{pkgver\}}"
source_line="  \"ZCode-\${pkgver}-mac-arm64.dmg::${pkgbuild_source_url}\""

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "0,/^[[:space:]]*\"ZCode-\\\${pkgver}-mac-arm64[.]dmg::.*\"/{s|^[[:space:]]*\"ZCode-\\\${pkgver}-mac-arm64[.]dmg::.*\"|${source_line}|}" \
  -e "0,/^[[:space:]]*'[0-9a-f]\\{64\\}'/{s/^[[:space:]]*'[0-9a-f]\\{64\\}'/  '${source_sha256}'/}" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
