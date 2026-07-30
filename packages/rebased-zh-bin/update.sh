#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REBASED_BIN_PKGBUILD_PATH="${SCRIPT_DIR}/../rebased-bin/PKGBUILD"
RELEASE_API_URL="https://api.github.com/repos/DetachHead/rebased/releases/latest"
PLUGIN_SCRIPT_URL="${PLUGIN_SCRIPT_URL:-https://raw.githubusercontent.com/duanluan/shell-scripts/main/prepare-jetbrains-zh-plugin.sh}"
PLUGIN_SOURCE_PATH="${SCRIPT_DIR}/assets/localization-zh-source.jar"
REBASED_IDE_DIR="${REBASED_IDE_DIR:-}"
ASSET_NAME="rebased.tar.gz"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg
require_command sha256sum
require_command tar

download_file() {
  local url="$1"
  local output_path="$2"

  curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "${output_path}" "${url}"
}

current_pkgver=""
current_pkgrel=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
fi

[[ -f "${PLUGIN_SOURCE_PATH}" ]] || {
  printf 'missing plugin source: %s\n' "${PLUGIN_SOURCE_PATH}" >&2
  exit 1
}

release_json="$(curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg name "${ASSET_NAME}" '[.assets[] | select(.name == $name)][0].browser_download_url')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve %s asset\n' "${ASSET_NAME}" >&2
  exit 1
fi

if [[ "${pkgver}" == "${current_pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
else
  pkgrel=1
fi

rebased_bin_min_pkgrel=1
if [[ -f "${REBASED_BIN_PKGBUILD_PATH}" ]]; then
  rebased_bin_pkgver="$(sed -n 's/^pkgver=//p' "${REBASED_BIN_PKGBUILD_PATH}" | head -n1)"
  rebased_bin_pkgrel="$(sed -n 's/^pkgrel=//p' "${REBASED_BIN_PKGBUILD_PATH}" | head -n1)"
  if [[ "${rebased_bin_pkgver}" == "${pkgver}" && "${rebased_bin_pkgrel}" =~ ^[0-9]+$ ]]; then
    rebased_bin_min_pkgrel="${rebased_bin_pkgrel}"
  fi
fi
if [[ "${pkgver}" == "1.1.5" && "${rebased_bin_min_pkgrel}" -lt 2 ]]; then
  rebased_bin_min_pkgrel=2
fi

plugin_output_dir="${SCRIPT_DIR}/assets/${pkgver}"
plugin_output_path="${plugin_output_dir}/localization-zh.jar"

mkdir -p "${plugin_output_dir}"
if [[ -n "${REBASED_IDE_DIR}" ]]; then
  ide_dir="${REBASED_IDE_DIR}"
else
  download_file "${asset_url}" "${TEMP_DIR}/${ASSET_NAME}"
  tar -xzf "${TEMP_DIR}/${ASSET_NAME}" -C "${TEMP_DIR}"
  ide_dir="$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'Rebased*' | sort | head -n1)"
fi
[[ -n "${ide_dir}" ]] || ide_dir="$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'idea-oss' | sort | head -n1)"
[[ -n "${ide_dir}" ]] || ide_dir="$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'idea-IC-*' | sort | head -n1)"
[[ -n "${ide_dir}" ]] || ide_dir="$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 2 -type f -name product-info.json -printf '%h\n' | sort | head -n1)"

if [[ -z "${ide_dir}" || ! -d "${ide_dir}" ]]; then
  printf 'failed to find extracted Rebased directory\n' >&2
  exit 1
fi

download_file "${PLUGIN_SCRIPT_URL}" "${TEMP_DIR}/prepare-jetbrains-zh-plugin.sh"
HOME="${TEMP_DIR}/home" XDG_DATA_HOME="${TEMP_DIR}/data" \
  bash "${TEMP_DIR}/prepare-jetbrains-zh-plugin.sh" \
    --source "${PLUGIN_SOURCE_PATH}" \
    --ide "${ide_dir}" \
    --output "${plugin_output_path}" >/dev/null

plugin_sha256="$(sha256sum "${plugin_output_path}" | cut -d ' ' -f 1)"

cat > "${PKGBUILD_PATH}" <<'PKGBUILD_EOF'
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-zh-bin
_pkgname=rebased
pkgver=__PKGVER__
pkgrel=__PKGREL__
pkgdesc='Chinese language pack for Rebased'
arch=('x86_64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('rebased-bin>=__PKGVER__-__REBASED_BIN_MIN_PKGREL__')
provides=('rebased-zh')
options=('!strip')
source=(
  "localization-zh.jar::https://raw.githubusercontent.com/duanluan/aur-packages/main/packages/rebased-zh-bin/assets/${pkgver}/localization-zh.jar"
)
sha256sums=(
  '__PLUGIN_SHA256__'
)

package() {
  install -Dm644 "${srcdir}/localization-zh.jar" "${pkgdir}/opt/${_pkgname}/plugins/localization-zh/lib/localization-zh.jar"
}
PKGBUILD_EOF

sed -i \
  -e "s/__PKGVER__/${pkgver}/g" \
  -e "s/__PKGREL__/${pkgrel}/g" \
  -e "s/__REBASED_BIN_MIN_PKGREL__/${rebased_bin_min_pkgrel}/g" \
  -e "s/__PLUGIN_SHA256__/${plugin_sha256}/g" \
  "${PKGBUILD_PATH}"

cd "${SCRIPT_DIR}"
rm -f localization-zh.jar
ln -s "assets/${pkgver}/localization-zh.jar" localization-zh.jar
makepkg --printsrcinfo > "${SRCINFO_PATH}"
printf '%s\n' "${pkgver}"
