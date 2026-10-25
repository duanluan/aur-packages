#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO='edison7009/EchoBird'

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
require_command mktemp
require_command sha256sum

asset_field() {
  local asset_name="$1"
  local field="$2"

  printf '%s\n' "${release_json}" | jq -r \
    --arg name "${asset_name}" --arg field "${field}" \
    '.assets[] | select(.name == $name) | .[$field] // empty' | head -n1
}

asset_sha256() {
  local arch_label="$1"
  local asset_name="EchoBird_${pkgver}_Linux_${arch_label}.deb"
  local asset_url
  local asset_digest
  local sha256

  asset_url="$(asset_field "${asset_name}" browser_download_url)"
  asset_digest="$(asset_field "${asset_name}" digest)"
  if [[ -z "${asset_url}" ]]; then
    printf 'failed to resolve release asset: %s\n' "${asset_name}" >&2
    exit 1
  fi

  sha256="${asset_digest#sha256:}"
  if [[ ! "${sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
    curl -fL --retry 5 --retry-all-errors "${asset_url}" \
      -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
    sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
  fi
  printf '%s\n' "${sha256}"
}

current_pkgver=''
current_pkgrel=''
current_license_sha256=''
current_x86_64_sha256=''
current_aarch64_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_license_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_x86_64_sha256="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_aarch64_sha256="$(awk -F"'" '/^sha256sums_aarch64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/${REPO}/releases/latest")"
tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == 'null' || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp echobird-bin.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

license_sha256="$(sha256sum "${SCRIPT_DIR}/LICENSE" | awk '{print $1}')"
x86_64_sha256="$(asset_sha256 x64)"
aarch64_sha256="$(asset_sha256 arm64)"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_license_sha256}" == "${license_sha256}" &&
      "${current_x86_64_sha256}" == "${x86_64_sha256}" &&
      "${current_aarch64_sha256}" == "${aarch64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
# Contributor: bruceutut <https://aur.archlinux.org/account/bruceutut>

pkgname=echobird-bin
_pkgname=echobird
_appname=EchoBird
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Desktop hub to manage AI coding tools, accounts and quota with smart routing (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/edison7009/EchoBird'
license=('MIT')
depends=(
  'cairo'
  'dbus'
  'gdk-pixbuf2'
  'glib2'
  'gtk3'
  'hicolor-icon-theme'
  'libayatana-appindicator'
  'libsoup3'
  'wayland'
  'webkit2gtk-4.1'
)
provides=("echobird=\${pkgver}")
conflicts=('echobird')
options=('!strip')
source=('LICENSE')
source_x86_64=("EchoBird_\${pkgver}_Linux_x64.deb::https://github.com/edison7009/EchoBird/releases/download/v\${pkgver}/EchoBird_\${pkgver}_Linux_x64.deb")
source_aarch64=("EchoBird_\${pkgver}_Linux_arm64.deb::https://github.com/edison7009/EchoBird/releases/download/v\${pkgver}/EchoBird_\${pkgver}_Linux_arm64.deb")
noextract=(
  "EchoBird_\${pkgver}_Linux_x64.deb"
  "EchoBird_\${pkgver}_Linux_arm64.deb"
)
sha256sums=('${license_sha256}')
sha256sums_x86_64=('${x86_64_sha256}')
sha256sums_aarch64=('${aarch64_sha256}')

package() {
  local deb
  case "\${CARCH}" in
    x86_64)
      deb="\${srcdir}/EchoBird_\${pkgver}_Linux_x64.deb"
      ;;
    aarch64)
      deb="\${srcdir}/EchoBird_\${pkgver}_Linux_arm64.deb"
      ;;
    *)
      printf 'unsupported architecture: %s\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  local extract_dir="\${srcdir}/deb-extract"
  local data_archives

  rm -rf "\${extract_dir}"
  install -dm755 "\${extract_dir}"
  bsdtar -C "\${extract_dir}" -xf "\${deb}"

  data_archives=("\${extract_dir}"/data.tar.*)
  if (( \${#data_archives[@]} != 1 )) || [[ ! -f "\${data_archives[0]}" ]]; then
    printf 'unable to locate the Debian data archive\n' >&2
    return 1
  fi
  bsdtar -C "\${pkgdir}" -xf "\${data_archives[0]}"

  # NVIDIA 显卡上 WebKitGTK 的 DMABUF 渲染器画不出内容，窗口全透明；
  # 真实二进制改名 echobird.bin 后留在 /usr/bin，Tauri 按可执行文件
  # 所在目录解析资源路径 /usr/lib/EchoBird，不能挪到别处
  mv "\${pkgdir}/usr/bin/echobird" "\${pkgdir}/usr/bin/echobird.bin"
  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/echobird" <<'WRAPPER'
#!/bin/bash
# WebKitGTK 的 DMABUF 渲染器在 NVIDIA 驱动下输出全透明画面，
# 默认关闭它；其他显卡想恢复硬件加速可把这个变量设为 0
export WEBKIT_DISABLE_DMABUF_RENDERER="\${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
exec -a echobird /usr/bin/echobird.bin "\$@"
WRAPPER

  # 托盘图标通过 dlopen 加载 libayatana-appindicator，二进制本身不直接
  # 链接它，上游 deb 同样把它声明为依赖，缺失时托盘不可用
  install -Dm644 "\${srcdir}/LICENSE" "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
