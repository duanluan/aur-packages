#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
UPDATE_API="https://tron.jiyunhudong.com/api/sdk/check_update2?pid=7617773946401724698&uid=&buildId="

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

update_json="$(curl -fsSL --retry 3 "${UPDATE_API}")"
pkgver="$(printf '%s\n' "${update_json}" | jq -r '.data.manifest.darwin.version')"
dmg_url="$(printf '%s\n' "${update_json}" | jq -r '.data.manifest.darwin.urls[] | select(.region == "cn") | .download_urls["x64"]')"
buildid="$(printf '%s\n' "${dmg_url}" | sed -nE 's|.*/7617773946401724698/([0-9]+)/.*|\1|p')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" || -z "${dmg_url}" || "${dmg_url}" == "null" || -z "${buildid}" ]]; then
  printf 'failed to resolve latest version/dmg url from update service\n' >&2
  exit 1
fi

current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
current_buildid="$(awk -F= '/^_buildid=/ {print $2; exit}' "${PKGBUILD_PATH}")"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_buildid}" == "${buildid}" ]]; then
  # 版本没变就不重新下载 200MB 的 dmg，校验和不可能变
  printf '%s-%s\n' "${pkgver}" "$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  exit 0
fi

tmpdir="$(mktemp -d -p /var/tmp coze-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fL --retry 5 --retry-all-errors "${dmg_url}" -o "${tmpdir}/coze.dmg" >/dev/null 2>&1

sha256="$(sha256sum "${tmpdir}/coze.dmg" | awk '{print $1}')"
current_sha256="$(awk "/^sha256sums=\\(/ {found=1; next} found && /'[0-9a-f]{64}'/ {gsub(/'/, \"\", \$1); print \$1; exit}" "${PKGBUILD_PATH}")"

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e 's/^pkgrel=.*/pkgrel=1/' \
  -e "s/^_buildid=.*/_buildid=${buildid}/" \
  -e "s/${current_sha256}/${sha256}/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "1"
