#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
DOWNLOAD_PAGE="https://agent.minimax.cn/download"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command grep
require_command makepkg
require_command sed
require_command sha256sum

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"

page="$(curl -fsSL --retry 5 --retry-all-errors "${DOWNLOAD_PAGE}")"
url_x64="$(printf '%s' "${page}" \
  | grep -oE 'https://filecdn\.minimax\.chat/public/minimax-agent-prod/release/MiniMax%20Code-[0-9]+\.[0-9]+\.[0-9]+\.dmg' \
  | head -n1)"
url_arm64="$(printf '%s' "${page}" \
  | grep -oE 'https://filecdn\.minimax\.chat/public/minimax-agent-prod/release/MiniMax%20Code-[0-9]+\.[0-9]+\.[0-9]+-arm64\.dmg' \
  | head -n1)"

if [[ -z "${url_x64}" || -z "${url_arm64}" ]]; then
  printf 'failed to resolve the macOS download urls from %s\n' "${DOWNLOAD_PAGE}" >&2
  exit 1
fi

pkgver="$(printf '%s' "${url_x64}" | sed -E 's/.*MiniMax%20Code-([0-9]+\.[0-9]+\.[0-9]+)\.dmg/\1/')"

if [[ -z "${pkgver}" ]] || ! [[ "${pkgver}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'failed to resolve the latest MiniMax Code desktop version\n' >&2
  exit 1
fi

if [[ "${current_pkgver}" == "${pkgver}" ]]; then
  printf '%s\n' "${pkgver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL --retry 5 --retry-all-errors --max-time 900 "${url_x64}" -o "${tmpdir}/x64.dmg" >/dev/null 2>&1
curl -fL --retry 5 --retry-all-errors --max-time 900 "${url_arm64}" -o "${tmpdir}/arm64.dmg" >/dev/null 2>&1
sha256_x64="$(sha256sum "${tmpdir}/x64.dmg" | awk '{print $1}')"
sha256_arm64="$(sha256sum "${tmpdir}/arm64.dmg" | awk '{print $1}')"

awk \
  -v pkgver="${pkgver}" \
  -v sha256_x64="${sha256_x64}" \
  -v sha256_arm64="${sha256_arm64}" '
    BEGIN { in_x64 = 0; x64_done = 0; in_arm = 0; arm_done = 0 }

    /^pkgver=/ {
      print "pkgver=" pkgver
      next
    }

    /^sha256sums_x86_64=\(/ {
      in_x64 = 1
      print
      next
    }

    /^sha256sums_aarch64=\(/ {
      in_arm = 1
      print
      next
    }

    in_x64 && !x64_done && /^[[:space:]]*'\''[0-9a-f]+'\''$/ {
      print "  '\''" sha256_x64 "'\''"
      x64_done = 1
      in_x64 = 0
      next
    }

    in_arm && !arm_done && /^[[:space:]]*'\''[0-9a-f]+'\''$/ {
      print "  '\''" sha256_arm64 "'\''"
      arm_done = 1
      in_arm = 0
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
