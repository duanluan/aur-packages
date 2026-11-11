#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REGISTRY_URL="https://registry.npmjs.org/@minimax-ai/code/latest"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command jq
require_command makepkg

metadata="$(curl -fsSL --retry 5 --retry-all-errors "${REGISTRY_URL}")"
pkgver="$(printf '%s\n' "${metadata}" | jq -r '.version')"
better_sqlite3_ver="$(printf '%s\n' "${metadata}" | jq -r '.optionalDependencies["better-sqlite3"] // empty')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]] \
  || ! [[ "${pkgver}" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
  printf 'failed to resolve latest @minimax-ai/code version\n' >&2
  exit 1
fi

if [[ -z "${better_sqlite3_ver}" ]]; then
  printf 'failed to resolve better-sqlite3 pin from upstream optionalDependencies\n' >&2
  exit 1
fi

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_better_sqlite3_ver="$(awk -F= '/^_better_sqlite3_ver=/ {print $2; exit}' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" \
  && "${current_better_sqlite3_ver}" == "${better_sqlite3_ver}" ]]; then
  printf '%s\n' "${pkgver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

awk \
  -v pkgver="${pkgver}" \
  -v better_sqlite3_ver="${better_sqlite3_ver}" '
    /^pkgver=/ {
      print "pkgver=" pkgver
      next
    }

    /^_better_sqlite3_ver=/ {
      print "_better_sqlite3_ver=" better_sqlite3_ver
      next
    }

    { print }
  ' "${PKGBUILD_PATH}" > "${tmpdir}/PKGBUILD"
mv "${tmpdir}/PKGBUILD" "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
