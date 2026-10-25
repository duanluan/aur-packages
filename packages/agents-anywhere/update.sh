#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO='anywhere-labs/Agents-Anywhere'

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

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# 仓库同时给 desktop-next 打 v0.x 标签，只跟随 desktop-workbench 的
# 正式版本线（v2 起的非 0 主版本）
tag_name="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/${REPO}/tags?per_page=100" |
  jq -r '[.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | select(.name | test("^v0\\.") | not) | .name] | .[0] // empty')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || -z "${pkgver}" ]]; then
  printf 'failed to resolve the latest desktop-workbench tag\n' >&2
  exit 1
fi

current_pkgver=''
current_pkgrel=''
current_tarball_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_tarball_sha256="$(awk -F"'" '/^sha256sums=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

tmpdir="$(mktemp -d -p /var/tmp agents-anywhere.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

# GitHub tag 归档不发布 API 摘要，校验和需要下载归档自行计算；
# 直连易失速，带失速检测并用镜像兜底
tarball="Agents-Anywhere-${pkgver}.tar.gz"
for round in 1 2 3; do
  curl -fL --retry 3 --retry-all-errors --speed-limit 1024 --speed-time 30 \
    --max-time 900 -C - \
    "https://github.com/${REPO}/archive/refs/tags/v${pkgver}.tar.gz" \
    -o "${tmpdir}/${tarball}" >/dev/null 2>&1 && break
  curl -fL --retry 3 --retry-all-errors --speed-limit 1024 --speed-time 30 \
    --max-time 900 -C - \
    "https://gh-proxy.com/https://github.com/${REPO}/archive/refs/tags/v${pkgver}.tar.gz" \
    -o "${tmpdir}/${tarball}" >/dev/null 2>&1 && break
done
[[ -s "${tmpdir}/${tarball}" ]] || {
  printf 'failed to download the source tarball\n' >&2
  exit 1
}
tarball_sha256="$(sha256sum "${tmpdir}/${tarball}" | awk '{print $1}')"

trap - EXIT
rm -rf "${tmpdir}"

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_tarball_sha256}" == "${tarball_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
#
# Built from the upstream source (desktop-workbench). The project publishes
# no Linux release: upstream ships macOS/Windows installers only, although
# the electron-builder config carries a Linux target. The bundle scripts
# download the uv and python-build-standalone runtimes for the build host
# architecture from their official releases.
#
# Note: the upstream repository carries no LICENSE file at the time of
# packaging; the license field stays NOASSERTION until upstream adds one.

pkgname=agents-anywhere
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Open-source cross-device AI agent workbench desktop app (built from source)'
arch=('x86_64' 'aarch64')
url='https://github.com/anywhere-labs/Agents-Anywhere'
license=('NOASSERTION')
depends=('gtk3' 'nss' 'alsa-lib' 'libxss' 'libxtst' 'libsecret' 'libappindicator-gtk3')
makedepends=('nodejs' 'curl')
options=('!strip' '!debug')
source=("Agents-Anywhere-\${pkgver}.tar.gz::https://github.com/anywhere-labs/Agents-Anywhere/archive/refs/tags/v\${pkgver}.tar.gz")
sha256sums=('${tarball_sha256}')

build() {
  cd "\${srcdir}/Agents-Anywhere-\${pkgver}/desktop-workbench"

  # corepack 从 registry 拉 yarn 4 时不要交互确认
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  # yarn 4 沿文件系统祖先链向上找项目根，用户家目录里误生成的
  # package.json 会被当成顶层项目（"doesn't seem to be part of the
  # project"）。空的 yarn.lock 把 workbench 声明为独立项目根，
  # 这是 yarn 报错信息里给出的官方解法
  : > yarn.lock
  # 上游没有提交 yarn.lock，依赖按 semver 浮动
  corepack yarn install

  # next/font/google 在构建期要从 Google Fonts 下载字体，离线或受限
  # 网络下构建失败；改为系统字体栈，只影响默认字体观感
  python - <<'PYEOF'
from pathlib import Path
import re
p = Path("renderer/src/app/layout.tsx")
s = p.read_text()
if 'from "next/font/google"' in s:
    s = s.replace(
        'import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";',
        '// [arch build] next/font/google requires Google Fonts access at build time')
    s = re.sub(r'const sans = Geist\(\{.*?\}\);', 'const sans = { variable: "--font-geist" };', s, flags=re.S)
    s = re.sub(r'const mono = Geist_Mono\(\{.*?\}\);', 'const mono = { variable: "--font-geist-mono" };', s, flags=re.S)
    s = re.sub(r'const serif = Instrument_Serif\(\{.*?\}\);', 'const serif = { variable: "--font-instrument-serif" };', s, flags=re.S)
    p.write_text(s)
c = Path("renderer/src/app/globals.css")
t = c.read_text()
t = t.replace("--font-sans: var(--font-geist);", "--font-sans: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, 'Noto Sans', sans-serif;")
t = t.replace("--font-heading: var(--font-geist);", "--font-heading: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, 'Noto Sans', sans-serif;")
t = t.replace("--font-mono: var(--font-geist-mono);", "--font-mono: ui-monospace, 'Cascadia Mono', 'JetBrains Mono', Menlo, Consolas, monospace;")
t = t.replace("--font-serif: var(--font-instrument-serif);", "--font-serif: Georgia, 'Times New Roman', serif;")
c.write_text(t)
print("fonts switched to system stacks")
PYEOF

  # prepare-uv.mjs 只会从 GitHub 直连下载且没有镜像变量；它要取四个
  # 文件（归档、官方 .sha256、两份许可证），download() 见文件已存在
  # 即跳过，所以预先放好。GitHub 优先，失败再走镜像
  aa_fetch() {
    local dest="\$1" u
    shift
    [[ -s "\${dest}" ]] && return 0
    for u in "\$@"; do
      curl -fsSL --retry 2 --speed-limit 1024 --speed-time 30 --max-time 600 \\
        -o "\${dest}" "\${u}" && return 0 || true
    done
    return 1
  }
  local uv_ver uv_triple uv_asset uv_cache uv_lic uv_gh uv_raw
  uv_ver="\$(sed -nE 's/.*UV_BUNDLE_VERSION \\|\\| \"([^\"]+)\".*/\\1/p' scripts/prepare-uv.mjs | head -n1)"
  case "\${CARCH}" in
    x86_64)  uv_triple='x86_64-unknown-linux-gnu' ;;
    aarch64) uv_triple='aarch64-unknown-linux-gnu' ;;
  esac
  uv_asset="uv-\${uv_triple}.tar.gz"
  uv_cache=".cache/uv/\${uv_ver}"
  uv_lic="build/uv/THIRD_PARTY_LICENSES/uv"
  uv_gh="https://github.com/astral-sh/uv/releases/download/\${uv_ver}/\${uv_asset}"
  uv_raw="https://raw.githubusercontent.com/astral-sh/uv/\${uv_ver}"
  install -dm755 "\${uv_cache}" "\${uv_lic}"
  aa_fetch "\${uv_cache}/\${uv_asset}" "\${uv_gh}" "https://gh-proxy.com/\${uv_gh}"
  aa_fetch "\${uv_cache}/\${uv_asset}.sha256" "\${uv_gh}.sha256" "https://gh-proxy.com/\${uv_gh}.sha256"
  aa_fetch "\${uv_lic}/LICENSE-MIT" "\${uv_raw}/LICENSE-MIT" "https://gh-proxy.com/\${uv_raw}/LICENSE-MIT"
  aa_fetch "\${uv_lic}/LICENSE-APACHE" "\${uv_raw}/LICENSE-APACHE" "https://gh-proxy.com/\${uv_raw}/LICENSE-APACHE"
  [[ -s "\${uv_cache}/\${uv_asset}" && -s "\${uv_cache}/\${uv_asset}.sha256" &&
     -s "\${uv_lic}/LICENSE-MIT" && -s "\${uv_lic}/LICENSE-APACHE" ]] || {
    printf 'failed to pre-seed the uv bundle cache\n' >&2
    return 1
  }

  # 捆绑 uv 与 python-build-standalone 运行时（按构建机架构取 linux 变体）
  corepack yarn bundle:uv
  corepack yarn bundle:python

  corepack yarn build
  corepack yarn exec electron-builder --linux dir
}

package() {
  local app_dir="\${srcdir}/Agents-Anywhere-\${pkgver}/desktop-workbench/release/linux-unpacked"

  install -dm755 "\${pkgdir}/opt/agents-anywhere"
  cp -a "\${app_dir}/." "\${pkgdir}/opt/agents-anywhere/"

  # chrome-sandbox 需要 setuid 才能在未启用 --no-sandbox 时工作
  chmod 4755 "\${pkgdir}/opt/agents-anywhere/chrome-sandbox"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/agents-anywhere" <<'LAUNCHER'
#!/usr/bin/env bash
exec /opt/agents-anywhere/agents-anywhere-desktop-workbench "\$@"
LAUNCHER

  install -Dm644 /dev/stdin "\${pkgdir}/usr/share/applications/agents-anywhere.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Agents Anywhere
Comment=Open-source cross-device AI agent workbench
Exec=agents-anywhere %U
Icon=agents-anywhere
Terminal=false
StartupNotify=true
StartupWMClass=Agents Anywhere
Categories=Development;Utility;
DESKTOP

  # 上游只提供一张源图标，按 hicolor 惯例放到 512x512
  install -Dm644 "\${app_dir}/resources/build/icon-mac-source.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/512x512/apps/agents-anywhere.png"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
