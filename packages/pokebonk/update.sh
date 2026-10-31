#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="CharcherGit/pokebonk-app"

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
require_command sha256sum

latest_release_tag() {
  local headers

  headers="$(curl -fsSLI "https://github.com/${REPO}/releases/latest")"
  printf '%s\n' "${headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1
}

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "https://api.github.com/repos/${REPO}/releases/latest")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
else
  tag_name="$(latest_release_tag)"
fi

pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp pokebonk-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

if [[ -n "${release_json}" ]]; then
  appimage_url="$(printf '%s\n' "${release_json}" | jq -r '.assets[] | select(.name | endswith("-linux-x86_64.AppImage")) | .browser_download_url' | head -n1)"
else
  appimage_url="https://github.com/${REPO}/releases/download/${tag_name}/PokeBonk-${pkgver}-linux-x86_64.AppImage"
fi

if [[ -z "${appimage_url}" || "${appimage_url}" == "null" ]]; then
  printf 'failed to resolve release asset: PokeBonk-*-linux-x86_64.AppImage\n' >&2
  exit 1
fi

curl -fL --retry 5 --retry-all-errors "${appimage_url}" -o "${tmpdir}/PokeBonk-${pkgver}-linux-x86_64.AppImage" >/dev/null 2>&1

appimage_sha256="$(sha256sum "${tmpdir}/PokeBonk-${pkgver}-linux-x86_64.AppImage" | awk '{print $1}')"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_sha256="$(awk -F"'" '
  $2 ~ /^[0-9a-f]{64}$/ { print $2; exit }
' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256}" == "${appimage_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "0,/^[[:space:]]*'[0-9a-f]\{64\}'/{s/^[[:space:]]*'[0-9a-f]\{64\}'/  '${appimage_sha256}'/}" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
