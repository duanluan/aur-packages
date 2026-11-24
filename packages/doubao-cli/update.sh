#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REGISTRY_URL="https://registry.npmjs.org/@bytedance/doubao-cli/latest"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command bsdtar
require_command curl
require_command jq
require_command makepkg
require_command sha256sum

curl_flags=(-fsSL --retry 5 --retry-all-errors --max-time 300)

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# npm 包本身只有启动脚本，平台运行时地址和校验值写在包内的 artifacts.json
metadata="$(curl "${curl_flags[@]}" "${REGISTRY_URL}")"
pkgver="$(printf '%s\n' "${metadata}" | jq -r '.version')"
tarball_url="$(printf '%s\n' "${metadata}" | jq -r '.dist.tarball')"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]] \
  || ! [[ "${pkgver}" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
  printf 'failed to resolve latest @bytedance/doubao-cli version\n' >&2
  exit 1
fi

curl "${curl_flags[@]}" "${tarball_url}" -o "${tmpdir}/npm-package.tgz"
bsdtar -xOf "${tmpdir}/npm-package.tgz" package/artifacts.json > "${tmpdir}/artifacts.json"

manifest_version="$(jq -r '.version' "${tmpdir}/artifacts.json")"
artifact_url="$(jq -r '.platforms["linux-x64"].url // empty' "${tmpdir}/artifacts.json")"
artifact_sha256="$(jq -r '.platforms["linux-x64"].sha256 // empty' "${tmpdir}/artifacts.json")"
artifact_root="$(jq -r '.platforms["linux-x64"].root // empty' "${tmpdir}/artifacts.json")"

if [[ "${manifest_version}" != "${pkgver}" ]]; then
  printf 'artifacts.json version %s does not match npm version %s\n' \
    "${manifest_version}" "${pkgver}" >&2
  exit 1
fi

if [[ "${artifact_root}" != "doubao-cli-${pkgver}-linux-x64" ]]; then
  printf 'unexpected upstream archive root: %s\n' "${artifact_root}" >&2
  exit 1
fi

if [[ ! "${artifact_url}" =~ ^https://lf-flow-web-cdn\.doubao\.com/ ]] \
  || [[ ! "${artifact_sha256}" =~ ^[a-f0-9]{64}$ ]]; then
  printf 'unexpected linux-x64 artifact entry: %s (%s)\n' \
    "${artifact_url}" "${artifact_sha256}" >&2
  exit 1
fi

# 清单里的校验值再对着实际文件核一遍，防止清单和压缩包不同步时发出坏包
curl "${curl_flags[@]}" "${artifact_url}" -o "${tmpdir}/artifact.tar.gz"
actual_sha256="$(sha256sum "${tmpdir}/artifact.tar.gz" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${artifact_sha256}" ]]; then
  printf 'artifact sha256 mismatch: manifest %s, downloaded %s\n' \
    "${artifact_sha256}" "${actual_sha256}" >&2
  exit 1
fi

current_pkgver=''
current_pkgrel=''
current_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

license_sha256="$(sha256sum "${SCRIPT_DIR}/LICENSE" | awk '{print $1}')"

if [[ "${current_pkgver}" == "${pkgver}" \
  && "${current_sha256}" == "${artifact_sha256}" \
  && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
#
# 豆包 CLI 官方只发布预编译产物，没有源码可编译，因此包名不带 -bin 后缀
# （见 docs/aur-packaging-rules.md 第 1 节）。
#
# 上游通过 npm 包 @bytedance/doubao-cli 分发：npm 包里只有启动脚本和
# artifacts.json 下载清单，真正的运行时是按平台下载的 linux-x64 压缩包。
# 本包直接打包 CDN 上的压缩包，不经过 npm，也不依赖 Node.js。
#
# 压缩包里的 doubao 按自身真实路径查找同目录的 resources/ 和 .so，所以
# /usr/bin/doubao 指向 /opt 下真身的软链接即可正常工作。

pkgname=doubao-cli
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Doubao CLI: terminal AI agent for Doubao, usable from scripts and automation workflows'
arch=('x86_64')
url='https://www.doubao.com/work/docs/zh-cn/doubao-cli'
license=('LicenseRef-Proprietary')
depends=(
  'glibc'
  'gcc-libs'
  'glib2'
  'gnutls'
  'nspr'
  'nss'
  'systemd-libs'
  'util-linux-libs'
  'zlib'
)
optdepends=(
  'curl: download the browser-use runtime'
  'dpkg: unpack the Chromium bundle used by browser-use'
  'python: create the browser-use virtual environment'
)
options=('!strip' '!debug')
source=(
  "doubao-cli-\${pkgver}-linux-x64.tar.gz::${artifact_url}"
  'LICENSE'
)
sha256sums=('${artifact_sha256}'
            '${license_sha256}')
noextract=("doubao-cli-\${pkgver}-linux-x64.tar.gz")

package() {
  install -dm755 "\${pkgdir}/opt/doubao-cli"
  bsdtar -C "\${pkgdir}/opt/doubao-cli" --strip-components=1 \\
    -xf "\${srcdir}/doubao-cli-\${pkgver}-linux-x64.tar.gz"

  find "\${pkgdir}/opt/doubao-cli" -type d -exec chmod 755 '{}' +
  find "\${pkgdir}/opt/doubao-cli" -type f -perm /111 -exec chmod 755 '{}' +
  find "\${pkgdir}/opt/doubao-cli" -type f ! -perm /111 -exec chmod 644 '{}' +

  install -dm755 "\${pkgdir}/usr/bin"
  ln -s /opt/doubao-cli/doubao "\${pkgdir}/usr/bin/doubao"

  install -Dm644 "\${srcdir}/LICENSE" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
  install -Dm644 "\${pkgdir}/opt/doubao-cli/clipboard-native-licenses.txt" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.clipboard-native"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
