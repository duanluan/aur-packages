#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
DOWNLOAD_URL="${DOWNLOAD_URL:-https://download.tessoa.com/tessoa/latest/tessoa.tar.gz}"
ETAG_PREFIX='# upstream etag:'

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command grep
require_command makepkg
require_command sha256sum
require_command tar

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-max-time 300 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    --speed-limit 1024 \
    --speed-time 60 \
    "$@"
}

# 官网只提供 latest 固定地址且没有版本接口，用响应 ETag 做低成本的变更探测。
upstream_etag="$(curl_retry --head "${DOWNLOAD_URL}" | tr -d '\r' | sed -n 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//p' | head -n1)"
if [[ -z "${upstream_etag}" ]]; then
  printf 'failed to resolve upstream etag: %s\n' "${DOWNLOAD_URL}" >&2
  exit 1
fi

current_etag="$(sed -n "s/^${ETAG_PREFIX} //p" "${PKGBUILD_PATH}" | head -n1)"
if [[ -z "${current_etag}" ]]; then
  printf 'missing etag marker in PKGBUILD: %s\n' "${PKGBUILD_PATH}" >&2
  exit 1
fi

if [[ "${upstream_etag}" == "${current_etag}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  printf 'up to date: %s\n' "${current_pkgver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl_retry --output "${tmpdir}/tessoa.tar.gz" "${DOWNLOAD_URL}" >/dev/null
upstream_sha256="$(sha256sum "${tmpdir}/tessoa.tar.gz" | awk '{print $1}')"

tar -xzf "${tmpdir}/tessoa.tar.gz" -C "${tmpdir}"
if [[ ! -f "${tmpdir}/tessoa/tessoa" ]]; then
  printf 'unexpected archive layout: binary not found at tessoa/tessoa\n' >&2
  exit 1
fi

# 版本号内嵌在二进制字符串里（形如 "tessoa 0.27.0"）。
pkgver="$(grep -aoE 'tessoa [0-9]+\.[0-9]+\.[0-9]+' "${tmpdir}/tessoa/tessoa" | head -n1 | awk '{print $2}')"
if [[ -z "${pkgver}" ]]; then
  printf 'failed to detect version from upstream binary\n' >&2
  exit 1
fi

current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"

if [[ "${pkgver}" != "${current_pkgver}" ]]; then
  pkgrel=1
else
  pkgrel=$((current_pkgrel + 1))
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s|^${ETAG_PREFIX} .*|${ETAG_PREFIX} ${upstream_etag}|" \
  -e "s/^sha256sums=.*/sha256sums=('${upstream_sha256}')/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
