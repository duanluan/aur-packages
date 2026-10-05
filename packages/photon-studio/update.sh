#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
DOWNLOAD_API='https://tenzen.studio/api/v1/photon/download'
CDN_BASE='https://downloads.tenzen.studio/photon/stable/linux'

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
require_command sed
require_command sha256sum

# The download API redirects to a versioned CDN URL like
# https://downloads.tenzen.studio/photon/stable/linux/0.1.42/Photon-Studio-0.1.42-linux-x64.flatpak
redirect_url="$(curl -fsSL --max-time 30 -o /dev/null -w '%{url_effective}' -L -r 0-0 "${DOWNLOAD_API}?platform=linux&arch=x64")"
pkgver="$(sed -nE 's|.*/stable/linux/([0-9]+(\.[0-9]+)+)/.*|\1|p' <<<"${redirect_url}")"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest version from %s\n' "${redirect_url}" >&2
  exit 1
fi

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}" 2>/dev/null || true)"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}" 2>/dev/null || true)"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  # CDN download paths include the version and are immutable, so an unchanged
  # version always means an unchanged artifact. Skip the huge re-download.
  (cd "${SCRIPT_DIR}" && makepkg --printsrcinfo > "${SRCINFO_PATH}")
  printf '%s-%s\n' "${pkgver}" "${current_pkgrel}"
  exit 0
fi

pkgrel=1

tmpdir="$(mktemp -d -p /var/tmp photon-studio-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

archive_path="${tmpdir}/Photon-Studio-${pkgver}-linux-x64.AppImage"
if [[ -n "${PHOTON_STUDIO_APPIMAGE:-}" ]]; then
  if [[ ! -f "${PHOTON_STUDIO_APPIMAGE}" ]]; then
    printf 'local archive does not exist: %s\n' "${PHOTON_STUDIO_APPIMAGE}" >&2
    exit 1
  fi
  archive_path="${PHOTON_STUDIO_APPIMAGE}"
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
    "${CDN_BASE}/${pkgver}/Photon-Studio-${pkgver}-linux-x64.AppImage" \
    --output "${archive_path}"
fi

archive_sha256="$(sha256sum "${archive_path}" | awk '{print $1}')"

# Only pkgver, pkgrel and the first sha256 entry (the AppImage) change here.
# Checksums of the local desktop/launcher/icon files stay untouched.
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
