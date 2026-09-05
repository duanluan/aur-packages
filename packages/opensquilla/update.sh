#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASES_URL="${RELEASES_URL:-https://api.github.com/repos/TokenRhythm/opensquilla/releases/latest}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg

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

release_json="$(curl_retry "${RELEASES_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name | ltrimstr("v")')"
dmg_sha256="$(printf '%s\n' "${release_json}" | jq -r --arg pkgver "${pkgver}" '.assets[] | select(.name == ("OpenSquilla-" + $pkgver + "-mac-arm64.dmg")) | .digest | sub("^sha256:"; "")')"

if [[ -z "${pkgver}" || -z "${dmg_sha256}" || "${dmg_sha256}" == "null" ]]; then
  printf 'failed to resolve latest OpenSquilla macOS release metadata\n' >&2
  exit 1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "0,/^[[:space:]]*'[0-9a-f]\{64\}'/{s/^[[:space:]]*'[0-9a-f]\{64\}'/  '${dmg_sha256}'/}" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
