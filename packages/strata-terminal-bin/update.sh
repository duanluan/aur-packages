#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO='Niko1221/Strata'

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command curl
require_command makepkg
require_command sha256sum

curl_flags=(-fsSL --retry 3 --retry-all-errors --max-time 60)

# 官方安装清单一行给出 linux-x86_64 终端的版本、文件名和官方 sha256：
# linux-x86_64 0.1.49.2 strata-control-0.1.49.2-linux-x86_64.tar.gz <sha256> <size>
manifest="$(curl "${curl_flags[@]}" \
  "https://github.com/${REPO}/releases/latest/download/install-manifest.txt")"
linux_line="$(printf '%s\n' "${manifest}" | awk '$1 == "linux-x86_64" {print; exit}')"
[[ -n "${linux_line}" ]] || {
  printf 'linux-x86_64 entry missing from install-manifest.txt\n' >&2
  exit 1
}
read -r _platform new_pkgver new_asset new_sha256 _size <<<"${linux_line}"

# 发布 tag（v0.2.4）和终端版本（0.1.49.2）是两条版本线，URL 两个都要
release_json="$(curl "${curl_flags[@]}" "https://api.github.com/repos/${REPO}/releases/latest")"
new_relver="$(printf '%s\n' "${release_json}" | sed -nE 's/.*"tag_name": *"([^"]+)".*/\1/p' | head -n1)"
new_relver="${new_relver#v}"
[[ "${new_relver}" =~ ^[0-9] ]] || {
  printf 'failed to resolve the latest release tag\n' >&2
  exit 1
}

current_pkgver=''
current_relver=''
current_pkgrel=''
current_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_relver="$(awk -F= '/^_relver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256="$(awk -F"'" '/^sha256sums=/ {print $4; exit}' "${PKGBUILD_PATH}")"
fi

license_sha256="$(sha256sum "${SCRIPT_DIR}/LICENSE" | awk '{print $1}')"

if [[ "${current_pkgver}" == "${new_pkgver}" && "${current_relver}" == "${new_relver}" &&
      "${current_sha256}" == "${new_sha256}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${new_pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
#
# Prebuilt Strata Terminal (the \`strata\` CLI). The terminal distribution is
# self-contained: it bundles its own Python 3.12 runtime, vocab data and
# tooling. The GPU-specific inference engine and the model weights are NOT
# bundled and are fetched by \`strata launch\` on first use, exactly like the
# official one-line installer does — see the README before packaging
# changes. Upstream publishes no ARM Linux builds.
#
# /usr/bin/strata is also owned by unrelated packages (the strata-bin file
# manager) and by same-project source builds (strata-engine-git, strata-rocm),
# hence the conflicts list.

pkgname=strata-terminal-bin
_relver=${new_relver}
pkgver=${new_pkgver}
pkgrel=${pkgrel}
pkgdesc='Strata Terminal: run Qwen3.8-Flash-Next and DeepSeek V4.1-Flash locally with an OpenAI/Anthropic-compatible API (prebuilt)'
arch=('x86_64')
url='https://github.com/Niko1221/Strata'
license=('MIT')
depends=('glibc')
provides=('strata' 'strata-terminal')
conflicts=('strata' 'strata-terminal' 'strata-engine' 'strata-bin' 'strata-rocm')
options=('!strip' '!debug')
source=(
  'LICENSE'
  "strata-terminal-\${pkgver}-linux-x86_64.tar.gz::https://github.com/Niko1221/Strata/releases/download/v\${_relver}/strata-control-\${pkgver}-linux-x86_64.tar.gz"
)
noextract=("strata-terminal-\${pkgver}-linux-x86_64.tar.gz")
sha256sums=('${license_sha256}'
            '${new_sha256}')

package() {
  install -dm755 "\${pkgdir}/opt/strata-terminal"
  bsdtar -C "\${pkgdir}/opt/strata-terminal" \\
    -xf "\${srcdir}/strata-terminal-\${pkgver}-linux-x86_64.tar.gz"

  # 启动脚本会解析符号链接定位自身目录，/usr/bin 下放绝对软链即可
  install -dm755 "\${pkgdir}/usr/bin"
  ln -s /opt/strata-terminal/bin/strata "\${pkgdir}/usr/bin/strata"

  install -Dm644 "\${srcdir}/LICENSE" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf 'terminal %s (release %s)\n' "${new_pkgver}" "${new_relver}"
