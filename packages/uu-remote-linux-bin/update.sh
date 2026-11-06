#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="VallierDev/uu-remote-linux"

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

tmpdir="$(mktemp -d -p /var/tmp uu-remote-linux-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

resolve_asset_url() {
  local suffix="$1"

  if [[ -n "${release_json}" ]]; then
    printf '%s\n' "${release_json}" | jq -r --arg suffix "${suffix}" \
      '.assets[] | select(.name | endswith($suffix)) | .browser_download_url' | head -n1
  else
    printf 'https://github.com/%s/releases/download/%s/uu-remote-linux-v%s-%s\n' \
      "${REPO}" "${tag_name}" "${pkgver}" "${suffix}"
  fi
}

x64_asset_url="$(resolve_asset_url 'x86_64-linux.tar.gz')"
arm64_asset_url="$(resolve_asset_url 'aarch64-linux.tar.gz')"

if [[ -z "${x64_asset_url}" || "${x64_asset_url}" == "null" ]]; then
  printf 'failed to resolve release asset: uu-remote-linux-*-x86_64-linux.tar.gz\n' >&2
  exit 1
fi

if [[ -z "${arm64_asset_url}" || "${arm64_asset_url}" == "null" ]]; then
  printf 'failed to resolve release asset: uu-remote-linux-*-aarch64-linux.tar.gz\n' >&2
  exit 1
fi

curl -fL --retry 5 --retry-all-errors "${x64_asset_url}" -o "${tmpdir}/x86_64.tar.gz" >/dev/null 2>&1
curl -fL --retry 5 --retry-all-errors "${arm64_asset_url}" -o "${tmpdir}/aarch64.tar.gz" >/dev/null 2>&1

sha256_x64="$(sha256sum "${tmpdir}/x86_64.tar.gz" | awk '{print $1}')"
sha256_arm64="$(sha256sum "${tmpdir}/aarch64.tar.gz" | awk '{print $1}')"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_sha256_x64="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_sha256_arm64="$(awk -F"'" '/^sha256sums_aarch64=/ {print $2; exit}' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256_x64}" == "${sha256_x64}" &&
      "${current_sha256_arm64}" == "${sha256_arm64}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${sha256_x64}')/" \
  -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${sha256_arm64}')/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
