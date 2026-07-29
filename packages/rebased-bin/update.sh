#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
LAUNCHER_PATH="${SCRIPT_DIR}/rebased.sh"
DESKTOP_FILE_PATH="${SCRIPT_DIR}/rebased.desktop"
RELEASE_API_URL="https://api.github.com/repos/DetachHead/rebased/releases/latest"
ASSET_X86_64_NAME="rebased.tar.gz"
ASSET_AARCH64_NAME="rebased-aarch64.tar.gz"

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

if [[ ! -f "${LAUNCHER_PATH}" || ! -f "${DESKTOP_FILE_PATH}" ]]; then
  printf 'missing local source files for rebased-bin\n' >&2
  exit 1
fi

launcher_sha256="$(sha256sum "${LAUNCHER_PATH}")"
launcher_sha256="${launcher_sha256%% *}"
desktop_file_sha256="$(sha256sum "${DESKTOP_FILE_PATH}")"
desktop_file_sha256="${desktop_file_sha256%% *}"

current_pkgver=""
current_pkgrel=""
current_sources=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_sources="$(
    sed -n '/^source_x86_64=/,/)/p;/^source_aarch64=/,/)/p' "${PKGBUILD_PATH}" |
      tr -d '\n'
  )"
fi

release_json="$(curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "${RELEASE_API_URL}")"
pkgver="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"

resolve_asset_url() {
  local name="$1"
  printf '%s\n' "${release_json}" |
    jq -r --arg name "${name}" '[.assets[] | select(.name == $name)][0].browser_download_url'
}

resolve_asset_digest() {
  local name="$1"
  printf '%s\n' "${release_json}" |
    jq -r --arg name "${name}" '[.assets[] | select(.name == $name)][0].digest'
}

resolve_sha256() {
  local name="$1"
  local url="$2"
  local digest="$3"

  if [[ -n "${digest}" && "${digest}" != "null" ]]; then
    printf '%s\n' "${digest#sha256:}"
    return
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  curl -fL --retry 5 --retry-delay 2 --retry-all-errors "${url}" -o "${tmpdir}/${name}" >/dev/null 2>&1
  sha256sum "${tmpdir}/${name}" | awk '{print $1}'
  rm -rf "${tmpdir}"
}

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed resolve latest tag\n' >&2
  exit 1
fi

asset_url_x86_64="$(resolve_asset_url "${ASSET_X86_64_NAME}")"
asset_url_aarch64="$(resolve_asset_url "${ASSET_AARCH64_NAME}")"
asset_digest_x86_64="$(resolve_asset_digest "${ASSET_X86_64_NAME}")"
asset_digest_aarch64="$(resolve_asset_digest "${ASSET_AARCH64_NAME}")"

if [[ -z "${asset_url_x86_64}" || "${asset_url_x86_64}" == "null" ]]; then
  printf 'failed to resolve %s asset\n' "${ASSET_X86_64_NAME}" >&2
  exit 1
fi

if [[ -z "${asset_url_aarch64}" || "${asset_url_aarch64}" == "null" ]]; then
  printf 'failed to resolve %s asset\n' "${ASSET_AARCH64_NAME}" >&2
  exit 1
fi

pkgbuild_url_x86_64="${asset_url_x86_64/\/download\/${pkgver}\//\/download\/\$\{pkgver\}\/}"
pkgbuild_url_aarch64="${asset_url_aarch64/\/download\/${pkgver}\//\/download\/\$\{pkgver\}\/}"
asset_sha256_x86_64="$(resolve_sha256 "${ASSET_X86_64_NAME}" "${asset_url_x86_64}" "${asset_digest_x86_64}")"
asset_sha256_aarch64="$(resolve_sha256 "${ASSET_AARCH64_NAME}" "${asset_url_aarch64}" "${asset_digest_aarch64}")"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_sources}" == *"source_x86_64"* && "${current_sources}" == *"source_aarch64"* ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<'PKGBUILD_EOF'
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=rebased-bin
_pkgname=rebased
pkgver=__PKGVER__
pkgrel=__PKGREL__
pkgdesc='Standalone JetBrains-based Git client (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/DetachHead/rebased'
license=('Apache-2.0')
depends=('fontconfig' 'giflib' 'hicolor-icon-theme' 'libdbusmenu-glib' 'ttf-font')
optdepends=('xdg-utils: open URLs from IDE')
provides=('rebased')
conflicts=('rebased')
options=('!strip')
source=("${_pkgname}.sh" "${_pkgname}.desktop")
source_x86_64=("${_pkgname}-${pkgver}-x86_64.tar.gz::__SOURCE_URL_X86_64__")
source_aarch64=("${_pkgname}-${pkgver}-aarch64.tar.gz::__SOURCE_URL_AARCH64__")
sha256sums=('__LAUNCHER_SHA256__'
            '__DESKTOP_FILE_SHA256__')
sha256sums_x86_64=('__ASSET_SHA256_X86_64__')
sha256sums_aarch64=('__ASSET_SHA256_AARCH64__')

package() {
  local app_dir
  local icon_png
  local icon_svg
  local install_root="${pkgdir}/opt/${_pkgname}"

  app_dir="$(find "${srcdir}" -mindepth 1 -maxdepth 1 -type d -name 'Rebased*' | sort | head -n1)"
  [[ -n "${app_dir}" ]] || app_dir="$(find "${srcdir}" -mindepth 1 -maxdepth 1 -type d -name 'idea-oss' | sort | head -n1)"
  [[ -n "${app_dir}" ]] || app_dir="$(find "${srcdir}" -mindepth 1 -maxdepth 1 -type d -name 'idea-IC-*' | sort | head -n1)"
  [[ -n "${app_dir}" ]] || app_dir="$(find "${srcdir}" -mindepth 1 -maxdepth 2 -type f -name product-info.json -printf '%h\n' | sort | head -n1)"
  if [[ -z "${app_dir}" ]]; then
    printf 'failed to find extracted Rebased application directory\n' >&2
    return 1
  fi

  install -dm755 "${install_root}"
  cp -a "${app_dir}/." "${install_root}/"

  if [[ ! -e "${install_root}/bin/rebased" ]]; then
    if [[ -x "${install_root}/bin/rebased.sh" ]]; then
      ln -s rebased.sh "${install_root}/bin/rebased"
    elif [[ -x "${install_root}/bin/idea" ]]; then
      ln -s idea "${install_root}/bin/rebased"
    elif [[ -x "${install_root}/bin/idea.sh" ]]; then
      ln -s idea.sh "${install_root}/bin/rebased"
    else
      printf 'failed to find Rebased launcher in %s/bin\n' "${app_dir}" >&2
      return 1
    fi
  fi

  icon_svg="${app_dir}/bin/rebased.svg"
  [[ -f "${icon_svg}" ]] || icon_svg="${app_dir}/bin/idea.svg"
  if [[ -f "${icon_svg}" ]]; then
    install -Dm644 "${icon_svg}" "${pkgdir}/usr/share/icons/hicolor/scalable/apps/rebased.svg"
  else
    printf 'failed to find Rebased SVG icon in %s/bin\n' "${app_dir}" >&2
    return 1
  fi

  icon_png="${app_dir}/bin/rebased.png"
  [[ -f "${icon_png}" ]] || icon_png="${app_dir}/bin/idea.png"
  if [[ -f "${icon_png}" ]]; then
    install -Dm644 "${icon_png}" "${pkgdir}/usr/share/pixmaps/rebased.png"
  fi

  install -Dm755 "${srcdir}/${_pkgname}.sh" "${pkgdir}/usr/bin/${_pkgname}"
  install -Dm644 "${app_dir}/LICENSE.txt" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE.txt"
  install -Dm644 "${srcdir}/${_pkgname}.desktop" "${pkgdir}/usr/share/applications/${_pkgname}.desktop"
}
PKGBUILD_EOF

sed -i \
  -e "s/__PKGVER__/${pkgver}/g" \
  -e "s/__PKGREL__/${pkgrel}/g" \
  -e "s#__SOURCE_URL_X86_64__#${pkgbuild_url_x86_64}#g" \
  -e "s#__SOURCE_URL_AARCH64__#${pkgbuild_url_aarch64}#g" \
  -e "s/__LAUNCHER_SHA256__/${launcher_sha256}/g" \
  -e "s/__DESKTOP_FILE_SHA256__/${desktop_file_sha256}/g" \
  -e "s/__ASSET_SHA256_X86_64__/${asset_sha256_x86_64}/g" \
  -e "s/__ASSET_SHA256_AARCH64__/${asset_sha256_aarch64}/g" \
  "${PKGBUILD_PATH}"

(cd "${SCRIPT_DIR}" && makepkg --printsrcinfo > "${SRCINFO_PATH}")

printf '%s\n' "${pkgver}"
