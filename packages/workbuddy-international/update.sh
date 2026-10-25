#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
API='https://www.workbuddy.ai/v2/update'
CN_API='https://copilot.tencent.com/v2/update'
DOWNLOAD_BASE='https://download.codebuddy.ai/workbuddy/saas'
CN_DOWNLOAD_BASE='https://download.codebuddy.cn/workbuddy/saas'

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
require_command python3
require_command sha256sum

feed_field() {
  local platform="$1"
  local field="$2"

  printf '%s\n' "${release_json}" | jq -r --arg f "${field}" '.[$f] // empty'
}

# 国际版 API 的 sha256hash 是 DMG 的哈希，PKGBUILD 用的是同版本的 zip 资产，
# 校验和必须下载 zip 自行计算
zip_sha256() {
  local platform="$1"
  local url="${DOWNLOAD_BASE}/${platform}/WorkBuddy-${platform}-${new_pkgver}-${new_build}.zip"
  local output="${tmpdir}/WorkBuddy-${platform}-${new_pkgver}-${new_build}.zip"

  if [[ ! -f "${output}" ]]; then
    curl -fL --retry 5 --retry-all-errors "${url}" -o "${output}" >/dev/null 2>&1
  fi
  sha256sum "${output}" | awk '{print $1}'
}

electron_asset_digest() {
  local arch_label="$1"
  local name="electron-v${new_electronver}-linux-${arch_label}.zip"

  printf '%s\n' "${electron_json}" | jq -r \
    --arg name "${name}" '.assets[] | select(.name == $name) | .digest // empty' \
    | sed 's/^sha256://'
}

# 国内版 API 的 sha256hash 就是 deb 本身的哈希（已实测核对），可直接采用
cn_feed() {
  local platform="$1"
  curl -fsSL --max-time 60 "${CN_API}?platform=${platform}"
}

extract_build_id() {
  basename "$1" .deb | grep -oE '[0-9a-f]{8}$' || true
}

current_pkgver=''
current_build=''
current_electronver=''
current_cn_pkgver=''
current_cn_build=''
current_pkgrel=''
current_patcher_sha256=''
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n -E 's/^_pkgver=(.+)$/\1/p' "${PKGBUILD_PATH}" | head -n1)"
  current_build="$(sed -n -E 's/^_build=(.+)$/\1/p' "${PKGBUILD_PATH}" | head -n1)"
  current_electronver="$(sed -n -E 's/^_electronver=(.+)$/\1/p' "${PKGBUILD_PATH}" | head -n1)"
  current_cn_pkgver="$(sed -n -E 's/^_cn_pkgver=(.+)$/\1/p' "${PKGBUILD_PATH}" | head -n1)"
  current_cn_build="$(sed -n -E 's/^_cn_build=(.+)$/\1/p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_patcher_sha256="$(sha256sum "${SCRIPT_DIR}/lib-apply-linux-patches.js" | awk '{print $1}')"
fi

release_json="$(curl -fsSL --max-time 60 "${API}?platform=workbuddy-darwin-x64")"
new_pkgver="$(feed_field x64 version)"
new_url="$(feed_field x64 url)"

arm_json="$(curl -fsSL --max-time 60 "${API}?platform=workbuddy-darwin-arm64")"
arm_pkgver="$(printf '%s\n' "${arm_json}" | jq -r '.version // empty')"
arm_url="$(printf '%s\n' "${arm_json}" | jq -r '.url // empty')"

if [[ -z "${new_pkgver}" || "${new_pkgver}" == 'null' || -z "${new_url}" ]]; then
  printf 'failed to resolve latest release from the update feed\n' >&2
  exit 1
fi
if [[ "${new_pkgver}" != "${arm_pkgver}" ]]; then
  printf 'platform version mismatch: x64=%s arm64=%s\n' "${new_pkgver}" "${arm_pkgver}" >&2
  exit 1
fi

# 构建号取资产文件名末尾的 8 位十六进制（...-5.8.4.41366630-73952edb.zip）
new_build="$(basename "${new_url}" .zip | grep -oE '[0-9a-f]{8}$' || true)"
if [[ -z "${new_build}" ]]; then
  printf 'failed to extract build id from: %s\n' "${new_url}" >&2
  exit 1
fi
if [[ "${arm_url}" != *"-${new_pkgver}-${new_build}.zip" ]]; then
  printf 'arm64 asset does not match the x64 build id: %s\n' "${arm_url}" >&2
  exit 1
fi

cn_x64_json="$(cn_feed workbuddy-linux-x64-deb)"
cn_arm_json="$(cn_feed workbuddy-linux-arm64-deb)"
cn_x64_url="$(printf '%s\n' "${cn_x64_json}" | jq -r '.url // empty')"
cn_arm_url="$(printf '%s\n' "${cn_arm_json}" | jq -r '.url // empty')"
cn_x64_sha256="$(printf '%s\n' "${cn_x64_json}" | jq -r '.sha256hash // empty' | sed 's/^sha256://')"
cn_arm64_sha256="$(printf '%s\n' "${cn_arm_json}" | jq -r '.sha256hash // empty' | sed 's/^sha256://')"
new_cn_pkgver="$(printf '%s\n' "${cn_x64_json}" | jq -r '.version // empty')"
new_cn_build="$(extract_build_id "${cn_x64_url}")"

if [[ -z "${new_cn_pkgver}" || "${new_cn_pkgver}" == 'null' || -z "${new_cn_build}" ]]; then
  printf 'failed to resolve the domestic-edition runtime feed\n' >&2
  exit 1
fi
if [[ "${new_cn_pkgver}" != "$(printf '%s\n' "${cn_arm_json}" | jq -r '.version // empty')" ]]; then
  printf 'domestic edition arch version mismatch\n' >&2
  exit 1
fi
if [[ ! "${cn_x64_sha256}" =~ ^[[:xdigit:]]{64}$ ]] || [[ ! "${cn_arm64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  printf 'domestic edition deb digests unavailable\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d -p /var/tmp workbuddy-international.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

# 捆绑的 Electron 版本写在 zip 内的 Electron Framework Info.plist 里，
# 用 HTTP Range 只读该文件，不必下载整个 zip
new_electronver="$(python3 "${SCRIPT_DIR}/remote-zip-read.py" "${new_url}" \
  'Electron Framework.framework/Versions/A/Resources/Info.plist' \
  --prop CFBundleVersion)"
if [[ ! "${new_electronver}" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  printf 'failed to detect bundled Electron version: %s\n' "${new_electronver}" >&2
  exit 1
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
electron_json="$(curl -fsSL "${curl_headers[@]}" \
  "https://api.github.com/repos/electron/electron/releases/tags/v${new_electronver}")"

electron_x64_sha256="$(electron_asset_digest x64)"
electron_arm64_sha256="$(electron_asset_digest arm64)"
if [[ ! "${electron_x64_sha256}" =~ ^[[:xdigit:]]{64}$ ]] ||
   [[ ! "${electron_arm64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  printf 'failed to resolve Electron asset digests for v%s\n' "${new_electronver}" >&2
  exit 1
fi

intl_unchanged=0
if [[ "${current_pkgver}" == "${new_pkgver}" && "${current_build}" == "${new_build}" &&
      "${current_electronver}" == "${new_electronver}" && -f "${PKGBUILD_PATH}" ]]; then
  intl_unchanged=1
fi

if [[ "${intl_unchanged}" -eq 1 ]]; then
  # 国际版版本没变就复用 PKGBUILD 里已钉的 zip 校验和，避免每次检查都
  # 重新下载约 1GB 资产
  darwin_x64_sha256="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  darwin_arm64_sha256="$(awk -F"'" '/^sha256sums_aarch64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
else
  darwin_x64_sha256="$(zip_sha256 darwin-x64)"
  darwin_arm64_sha256="$(zip_sha256 darwin-arm64)"
fi

if [[ ! "${darwin_x64_sha256}" =~ ^[[:xdigit:]]{64}$ ]] ||
   [[ ! "${darwin_arm64_sha256}" =~ ^[[:xdigit:]]{64}$ ]]; then
  printf 'failed to resolve darwin zip checksums\n' >&2
  exit 1
fi

trap - EXIT
rm -rf "${tmpdir}"

sha_install="$(sha256sum "${SCRIPT_DIR}/install.sh" | awk '{print $1}')"
sha_libcommon="$(sha256sum "${SCRIPT_DIR}/lib-common.sh" | awk '{print $1}')"
sha_libdmg="$(sha256sum "${SCRIPT_DIR}/lib-dmg.sh" | awk '{print $1}')"
sha_libelectron="$(sha256sum "${SCRIPT_DIR}/lib-electron.sh" | awk '{print $1}')"
sha_libnative="$(sha256sum "${SCRIPT_DIR}/lib-native-modules.sh" | awk '{print $1}')"
sha_libpatches="$(sha256sum "${SCRIPT_DIR}/lib-linux-patches.sh" | awk '{print $1}')"
sha_applypatches="$(sha256sum "${SCRIPT_DIR}/lib-apply-linux-patches.js" | awk '{print $1}')"
sha_desktop="$(sha256sum "${SCRIPT_DIR}/workbuddy-international.desktop" | awk '{print $1}')"
sha_licport="$(sha256sum "${SCRIPT_DIR}/LICENSE.port-tool" | awk '{print $1}')"
sha_disclaimer="$(sha256sum "${SCRIPT_DIR}/DISCLAIMER" | awk '{print $1}')"

if [[ "${current_pkgver}" == "${new_pkgver}" && "${current_build}" == "${new_build}" &&
      "${current_electronver}" == "${new_electronver}" &&
      "${current_cn_pkgver}" == "${new_cn_pkgver}" && "${current_cn_build}" == "${new_cn_build}" &&
      "${current_patcher_sha256}" == "${sha_applypatches}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${new_pkgver}" && "${current_build}" == "${new_build}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>
# Contributor: wasdxl <https://aur.archlinux.org/account/wasdxl>
#
# Unofficial Linux port: the WorkBuddy international edition (workbuddy.ai)
# publishes no Linux build. This package converts the official macOS build to
# a Linux Electron app on the user's machine; nothing proprietary is
# redistributed. Conversion toolchain vendored from the MIT-licensed
# community project workbuddy-linux (see LICENSE.port-tool); see DISCLAIMER.
#
# The node/python session runtimes are taken from the official domestic-
# edition Linux deb (download.codebuddy.cn): the international darwin build
# bundles macOS/Windows runtimes only, while the app expects
# resources/runtime/{node,python} on Linux. The runtimes are edition-
# agnostic and pinned to their own upstream version.

pkgname=workbuddy-international
_pkgver=${new_pkgver}
_build=${new_build}
_electronver=${new_electronver}
_cn_pkgver=${new_cn_pkgver}
_cn_build=${new_cn_build}
pkgver=\${_pkgver}_\${_build}
pkgrel=${pkgrel}
pkgdesc='AI Agent for everyday office work - WorkBuddy international edition (unofficial Linux port)'
arch=('x86_64' 'aarch64')
url='https://www.workbuddy.ai'
license=('NOASSERTION')
depends=('libsecret' 'libappindicator-gtk3' 'nss' 'alsa-lib' 'gtk3' 'libxss')
makedepends=('nodejs' 'npm' 'p7zip' 'unzip' 'python' 'imagemagick')
optdepends=('gnome-shell-extension-appindicator: tray icon support')
options=('!strip' '!debug')
provides=('workbuddy-international-bin')
conflicts=('workbuddy-international-bin')
source=(
  'install.sh'
  'lib-common.sh'
  'lib-dmg.sh'
  'lib-electron.sh'
  'lib-native-modules.sh'
  'lib-linux-patches.sh'
  'lib-apply-linux-patches.js'
  'workbuddy-international.desktop'
  'LICENSE.port-tool'
  'DISCLAIMER'
)
source_x86_64=(
  "WorkBuddy-darwin-x64-\${_pkgver}-\${_build}.zip::https://download.codebuddy.ai/workbuddy/saas/darwin-x64/WorkBuddy-darwin-x64-\${_pkgver}-\${_build}.zip"
  "electron-v\${_electronver}-linux-x64.zip::https://github.com/electron/electron/releases/download/v\${_electronver}/electron-v\${_electronver}-linux-x64.zip"
  "WorkBuddy-linux-x64-deb-\${_cn_pkgver}-\${_cn_build}.deb::https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
)
source_aarch64=(
  "WorkBuddy-darwin-arm64-\${_pkgver}-\${_build}.zip::https://download.codebuddy.ai/workbuddy/saas/darwin-arm64/WorkBuddy-darwin-arm64-\${_pkgver}-\${_build}.zip"
  "electron-v\${_electronver}-linux-arm64.zip::https://github.com/electron/electron/releases/download/v\${_electronver}/electron-v\${_electronver}-linux-arm64.zip"
  "WorkBuddy-linux-arm64-deb-\${_cn_pkgver}-\${_cn_build}.deb::https://download.codebuddy.cn/workbuddy/saas/linux-arm64-deb/WorkBuddy-linux-arm64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
)
noextract=(
  "WorkBuddy-linux-x64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
  "WorkBuddy-linux-arm64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
)
sha256sums=('${sha_install}'
            '${sha_libcommon}'
            '${sha_libdmg}'
            '${sha_libelectron}'
            '${sha_libnative}'
            '${sha_libpatches}'
            '${sha_applypatches}'
            '${sha_desktop}'
            '${sha_licport}'
            '${sha_disclaimer}')
sha256sums_x86_64=('${darwin_x64_sha256}'
                   '${electron_x64_sha256}'
                   '${cn_x64_sha256}')
sha256sums_aarch64=('${darwin_arm64_sha256}'
                    '${electron_arm64_sha256}'
                    '${cn_arm64_sha256}')

build() {
  local darwin_zip electron_zip cn_deb app_bundle

  case "\${CARCH}" in
    x86_64)
      darwin_zip="WorkBuddy-darwin-x64-\${_pkgver}-\${_build}.zip"
      electron_zip="electron-v\${_electronver}-linux-x64.zip"
      cn_deb="WorkBuddy-linux-x64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
      ;;
    aarch64)
      darwin_zip="WorkBuddy-darwin-arm64-\${_pkgver}-\${_build}.zip"
      electron_zip="electron-v\${_electronver}-linux-arm64.zip"
      cn_deb="WorkBuddy-linux-arm64-deb-\${_cn_pkgver}-\${_cn_build}.deb"
      ;;
    *)
      printf 'unsupported architecture: %s\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  rm -rf "\${srcdir}/app-extract"
  install -dm755 "\${srcdir}/app-extract"
  # __MACOSX 是 macOS 打包时混入的资源叉元数据，解包时直接排除，
  # 避免 find 选到错误的 .app
  unzip -q "\${srcdir}/\${darwin_zip}" -d "\${srcdir}/app-extract" -x '__MACOSX/*'

  app_bundle="\$(find "\${srcdir}/app-extract" -maxdepth 2 -name '*.app' -type d | sort | head -n1)"
  [[ -n "\${app_bundle}" ]] || { printf 'no .app bundle found in the darwin zip\n' >&2; return 1; }

  WORKBUDDY_APP_ID='WorkBuddy AI' \\
  WORKBUDDY_APP_DISPLAY_NAME='WorkBuddy AI (International)' \\
  WORKBUDDY_INSTALL_DIR="\${srcdir}/workbuddy-app" \\
  WORKBUDDY_ELECTRON_ZIP="\${srcdir}/\${electron_zip}" \\
    bash "\${srcdir}/install.sh" "\${app_bundle}"

  # 从国内版官方 Linux deb 提取会话运行时。国际版的 darwin 包只在
  # win32/darwin 条目下捆绑运行时，Linux 条目（node.tar.gz/python.tar.gz）
  # 实际不存在；缺失时 daemon 反复退出并弹 "critical component" 警告
  rm -rf "\${srcdir}/cn-deb-extract"
  install -dm755 "\${srcdir}/cn-deb-extract"
  bsdtar -C "\${srcdir}/cn-deb-extract" -xf "\${srcdir}/\${cn_deb}"
  bsdtar -C "\${srcdir}/cn-deb-extract" -xf "\${srcdir}/cn-deb-extract"/data.tar.* \\
    ./opt/WorkBuddy/resources/runtime

  local runtime_dir="\${srcdir}/cn-deb-extract/opt/WorkBuddy/resources/runtime"
  [[ -x "\${runtime_dir}/node/bin/node" && -x "\${runtime_dir}/python/bin/python3" ]] || {
    printf 'session runtimes missing from the domestic deb: %s\n' "\${runtime_dir}" >&2
    return 1
  }
  rm -rf "\${srcdir}/workbuddy-app/resources/runtime"
  cp -a "\${runtime_dir}" "\${srcdir}/workbuddy-app/resources/runtime"
}

package() {
  install -dm755 "\${pkgdir}/opt/workbuddy-international"
  cp -a "\${srcdir}/workbuddy-app/." "\${pkgdir}/opt/workbuddy-international/"

  # The helper desktop file written by install.sh embeds the build-time
  # srcdir in Exec=; point it at the final install location instead.
  sed -i "s|\${srcdir}/workbuddy-app|/opt/workbuddy-international|g" \\
    "\${pkgdir}/opt/workbuddy-international/.workbuddy-linux/WorkBuddy AI.desktop" 2>/dev/null || true

  # Desktop entry: named exactly after the app's Wayland app_id ("WorkBuddy AI")
  # so the task manager associates windows with this entry and its icon.
  install -Dm644 "\${srcdir}/workbuddy-international.desktop" \\
    "\${pkgdir}/usr/share/applications/WorkBuddy AI.desktop"

  # Icons: theme-integrated hicolor entry plus pixmaps fallback
  install -Dm644 "\${srcdir}/workbuddy-app/.workbuddy-linux/workbuddy.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/256x256/apps/workbuddy-international.png"
  install -Dm644 "\${srcdir}/workbuddy-app/.workbuddy-linux/workbuddy.png" \\
    "\${pkgdir}/usr/share/pixmaps/workbuddy-international.png"

  # Launcher
  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/workbuddy-international" <<'LAUNCHER'
#!/usr/bin/env bash
exec /opt/workbuddy-international/start.sh "\$@"
LAUNCHER

  # Licenses / notices
  install -Dm644 "\${srcdir}/LICENSE.port-tool" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE.port-tool"
  install -Dm644 "\${srcdir}/DISCLAIMER" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/DISCLAIMER"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s_%s (runtime %s_%s)\n' \
  "${new_pkgver}" "${new_build}" "${new_cn_pkgver}" "${new_cn_build}"
