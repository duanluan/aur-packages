#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
VERSION_URL="${VERSION_URL:-https://zcode.z.ai/en}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://cdn-zcode.z.ai/zcode/electron/releases}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command rg
require_command awk
require_command sha256sum
require_command makepkg

curl_retry() {
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
    --speed-limit 1024 \
    --speed-time 60 \
    "$@"
}

target_pkgver="${PKGVER:-}"

if [[ -n "${target_pkgver}" ]]; then
  pkgver="${target_pkgver}"
  x64_url="${RELEASE_BASE_URL}/${pkgver}/linux-x64/ZCode-${pkgver}-linux-x64.deb"
  arm64_url="${RELEASE_BASE_URL}/${pkgver}/linux-arm64/ZCode-${pkgver}-linux-arm64.deb"
  arm64_pkgver="${pkgver}"
else
  page="$(curl -fsSL "${VERSION_URL}")"
  x64_url="$(
    printf '%s\n' "${page}" |
      rg -o 'https://[^"'\'' ]+/ZCode-[0-9][0-9.]*-linux-x64[.]deb' |
      head -n1
  )"
  pkgver="$(printf '%s\n' "${x64_url}" | sed -n 's|.*/ZCode-\([0-9][0-9.]*\)-linux-x64[.]deb$|\1|p')"
  arm64_url="$(
    printf '%s\n' "${page}" |
      rg -o 'https://[^"'\'' ]+/ZCode-[0-9][0-9.]*-linux-arm64[.]deb' |
      head -n1
  )"
  arm64_pkgver="$(printf '%s\n' "${arm64_url}" | sed -n 's|.*/ZCode-\([0-9][0-9.]*\)-linux-arm64[.]deb$|\1|p')"
fi

if [[ -z "${x64_url}" || -z "${pkgver}" || -z "${arm64_url}" || "${arm64_pkgver}" != "${pkgver}" ]]; then
  printf 'failed to resolve latest ZCode Linux deb version\n' >&2
  exit 1
fi

# 防降级：新版可能先上 CDN、官网下载页仍指旧版；解析到的版本低于当前已发布
# 版本时保持现状，避免每日自动更新把已发布的高版本改回旧版
current_pkgver_pre="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
if [[ -n "${current_pkgver_pre}" && "${current_pkgver_pre}" != "${pkgver}" ]]; then
  lower_of_two="$(printf '%s\n%s\n' "${pkgver}" "${current_pkgver_pre}" | sort -V | head -n1)"
  if [[ "${lower_of_two}" == "${pkgver}" ]]; then
    printf 'skip: resolved %s <= current %s\n' "${pkgver}" "${current_pkgver_pre}" >&2
    exit 0
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl_retry "${x64_url}" -o "${tmpdir}/ZCode-${pkgver}-linux-x64.deb" >/dev/null
curl_retry "${arm64_url}" -o "${tmpdir}/ZCode-${pkgver}-linux-arm64.deb" >/dev/null
x64_sha256="$(sha256sum "${tmpdir}/ZCode-${pkgver}-linux-x64.deb" | awk '{print $1}')"
arm64_sha256="$(sha256sum "${tmpdir}/ZCode-${pkgver}-linux-arm64.deb" | awk '{print $1}')"
x64_pkgbuild_url="${x64_url//${pkgver}/\$\{pkgver\}}"
arm64_pkgbuild_url="${arm64_url//${pkgver}/\$\{pkgver\}}"
x64_source_line="source_x86_64=(\"ZCode-\${pkgver}-linux-x64.deb::${x64_pkgbuild_url}\")"
arm64_source_line="source_aarch64=(\"ZCode-\${pkgver}-linux-arm64.deb::${arm64_pkgbuild_url}\")"

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_x64_sha256="$(sed -n "s/^sha256sums_x86_64=('\([0-9a-f]\{64\}\)')/\1/p" "${PKGBUILD_PATH}")"
current_arm64_sha256="$(sed -n "s/^sha256sums_aarch64=('\([0-9a-f]\{64\}\)')/\1/p" "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_x64_sha256}" == "${x64_sha256}" &&
      "${current_arm64_sha256}" == "${arm64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" &&
        "${current_pkgrel}" =~ ^[0-9]+$ &&
        "${current_x64_sha256}" =~ ^[0-9a-f]{64}$ &&
        "${current_arm64_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s|^source_x86_64=.*|${x64_source_line}|" \
  -e "s|^source_aarch64=.*|${arm64_source_line}|" \
  -e "s|^sha256sums_x86_64=.*|sha256sums_x86_64=('${x64_sha256}')|" \
  -e "s|^sha256sums_aarch64=.*|sha256sums_aarch64=('${arm64_sha256}')|" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
