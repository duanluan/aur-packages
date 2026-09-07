#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
DOWNLOAD_URL='https://file-assets-cdn.oss-cn-hangzhou.aliyuncs.com/download/Apifox-linux-manual-latest.tar.gz'

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
require_command tar

tmpdir="$(mktemp -d -p /var/tmp apifox-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

archive_path="${tmpdir}/Apifox-linux-manual-latest.tar.gz"
if [[ -n "${APIFOX_ARCHIVE:-}" ]]; then
  if [[ ! -f "${APIFOX_ARCHIVE}" ]]; then
    printf 'local archive does not exist: %s\n' "${APIFOX_ARCHIVE}" >&2
    exit 1
  fi
  archive_path="${APIFOX_ARCHIVE}"
else
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "${DOWNLOAD_URL}" \
    --output "${archive_path}"
fi

top_level="$(tar -tzf "${archive_path}" | awk -F/ 'NF >= 2 && $1 != "" && first == "" {first=$1} END {print first}')"
if [[ -z "${top_level}" ]]; then
  printf 'failed to resolve archive top-level directory\n' >&2
  exit 1
fi

metadata_path="${top_level}/resources/app.asar.unpacked/package.json"
metadata="$(tar -xOf "${archive_path}" "${metadata_path}")"
pkgver="$(printf '%s\n' "${metadata}" | awk -F'"' '/"version"[[:space:]]*:/ {print $4; exit}')"
if [[ -z "${pkgver}" || ! "${pkgver}" =~ ^[0-9]+(\.[0-9]+){2}([+-][0-9A-Za-z.-]+)?$ ]]; then
  printf 'failed to resolve a valid Apifox version from %s\n' "${metadata_path}" >&2
  exit 1
fi

archive_sha256="$(sha256sum "${archive_path}" | awk '{print $1}')"
current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_sha256="$(awk -F"'" '
  $2 ~ /^[0-9a-f]{64}$/ { print $2; exit }
' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256}" == "${archive_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "0,/^[[:space:]]*'[0-9a-f]\{64\}'/{s/^[[:space:]]*'[0-9a-f]\{64\}'/  '${archive_sha256}'/}" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
