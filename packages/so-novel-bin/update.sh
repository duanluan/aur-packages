#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO="freeok/so-novel"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command gh
require_command makepkg
require_command sha256sum

current_pkgver=""
current_pkgrel=""
current_sha256_x64=""
current_sha256_arm64=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256_x64="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256_arm64="$(awk -F"'" '/^sha256sums_aarch64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

tag_name="$(gh release list -R "${REPO}" --limit 1 --json tagName --jq '.[0].tagName')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || -z "${pkgver}" || "${tag_name}" == "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

gh release download "${tag_name}" -R "${REPO}" -p 'sonovel-linux_x64.tar.gz' -D "${tmpdir}" >/dev/null
gh release download "${tag_name}" -R "${REPO}" -p 'sonovel-linux_arm64.tar.gz' -D "${tmpdir}" >/dev/null

sha256_x64="$(sha256sum "${tmpdir}/sonovel-linux_x64.tar.gz" | awk '{print $1}')"
sha256_arm64="$(sha256sum "${tmpdir}/sonovel-linux_arm64.tar.gz" | awk '{print $1}')"

trap - EXIT
rm -rf "${tmpdir}"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256_x64}" == "${sha256_x64}" &&
      "${current_sha256_arm64}" == "${sha256_arm64}" ]]; then
  pkgrel="${current_pkgrel}"
else
  if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
    pkgrel="$((current_pkgrel + 1))"
  else
    pkgrel=1
  fi
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=so-novel-bin
_pkgname=so-novel
_appdir=sonovel
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Universal web content extraction and ebook export tool (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/freeok/so-novel'
license=('AGPL-3.0-only')
depends=('glibc')
provides=('so-novel' 'sonovel')
conflicts=('so-novel' 'sonovel')
options=('!strip')
source_x86_64=("sonovel-linux_x64-\${pkgver}.tar.gz::https://github.com/freeok/so-novel/releases/download/v\${pkgver}/sonovel-linux_x64.tar.gz")
source_aarch64=("sonovel-linux_arm64-\${pkgver}.tar.gz::https://github.com/freeok/so-novel/releases/download/v\${pkgver}/sonovel-linux_arm64.tar.gz")
sha256sums_x86_64=('${sha256_x64}')
sha256sums_aarch64=('${sha256_arm64}')

package() {
  local bundle_dir

  case "\${CARCH}" in
    x86_64)
      bundle_dir="\${srcdir}/sonovel-linux_x64"
      ;;
    aarch64)
      bundle_dir="\${srcdir}/sonovel-linux_arm64"
      ;;
    *)
      printf 'unsupported architecture: %s\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  install -dm755 "\${pkgdir}/opt/\${_appdir}" "\${pkgdir}/usr/bin"
  cp -a "\${bundle_dir}/." "\${pkgdir}/opt/\${_appdir}/"

  find "\${pkgdir}/opt/\${_appdir}" -type d -exec chmod 755 '{}' +
  find "\${pkgdir}/opt/\${_appdir}" -type f -exec chmod 644 '{}' +
  chmod 755 "\${pkgdir}/opt/\${_appdir}/run-linux.sh"
  chmod 755 "\${pkgdir}/opt/\${_appdir}/runtime/bin/"*
  find "\${pkgdir}/opt/\${_appdir}/runtime/lib" -type f -name '*.so' -exec chmod 755 '{}' +

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
set -eu

app_dir=/opt/sonovel
data_dir="\${XDG_DATA_HOME:-\${HOME}/.local/share}/sonovel"
config_file="\${XDG_CONFIG_HOME:-\${HOME}/.config}/sonovel/config.ini"
config_dir=\$(dirname "\${config_file}")

mkdir -p "\${data_dir}" "\${config_dir}"

if [ ! -f "\${config_file}" ]; then
  cp "\${app_dir}/config.ini" "\${config_file}"
fi

if [ ! -d "\${data_dir}/rules" ]; then
  cp -a "\${app_dir}/rules" "\${data_dir}/rules"
fi

cd "\${data_dir}"
exec "\${app_dir}/runtime/bin/java" \\
  -XX:+UseZGC \\
  -XX:+ZGenerational \\
  -Dconfig.file="\${config_file}" \\
  -Dmode="\${SONOVEL_MODE:-tui}" \\
  -jar "\${app_dir}/app.jar" "\$@"
SCRIPT

  ln -s "\${_pkgname}" "\${pkgdir}/usr/bin/sonovel"
}
EOF

cd "${SCRIPT_DIR}"
makepkg --printsrcinfo > "${SRCINFO_PATH}"

printf '%s\n' "${pkgver}"
