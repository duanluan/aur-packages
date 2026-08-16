#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_URL="${RELEASE_URL:-https://github.com/BigPizzaV3/CodexPlusPlus/releases/latest}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command makepkg
require_command sha256sum

tag_name="${TAG_NAME:-$(curl -fsSIL -o /dev/null -w '%{url_effective}' "${RELEASE_URL}" | sed 's#/$##; s#.*/##')}"
pkgver="${tag_name#v}"
current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" 2>/dev/null | head -n1)"
current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" 2>/dev/null | head -n1)"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" ]]; then
  printf 'failed to resolve latest tag\n' >&2
  exit 1
fi

source_url="https://github.com/BigPizzaV3/CodexPlusPlus/archive/refs/tags/v${pkgver}.tar.gz"
tmpdir="$(mktemp -d -p /var/tmp codex-plus-plus-update.XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

TMPDIR=/var/tmp curl -fL "${source_url}" -o "${tmpdir}/codex-plus-plus-${pkgver}.tar.gz" >/dev/null 2>&1
source_sha256="$(sha256sum "${tmpdir}/codex-plus-plus-${pkgver}.tar.gz" | awk '{print $1}')"
wrapper_sha256="$(sha256sum "${SCRIPT_DIR}/codex-desktop-app-wrapper.sh" | awk '{print $1}')"
manager_sha256="$(sha256sum "${SCRIPT_DIR}/codex-plus-plus.sh" | awk '{print $1}')"
linux_port_patch="${SCRIPT_DIR}/codex-plus-plus-linux-port-fallback.patch"
linux_port_patch_sha256="$(sha256sum "${linux_port_patch}" | awk '{print $1}')"
hook_sha256="$(sha256sum "${SCRIPT_DIR}/90-codex-plus-plus-reapply.hook" | awk '{print $1}')"
desktop_sha256="$(sha256sum "${SCRIPT_DIR}/codex-plus-plus.desktop" | awk '{print $1}')"

if [[ -n "${PKGREL:-}" ]]; then
  pkgrel="${PKGREL}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${current_pkgrel}"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=codex-plus-plus
pkgver=${pkgver}
pkgrel=${pkgrel}
epoch=1
pkgdesc='Codex++ manual injection bridge for the ChatGPT desktop app'
arch=('x86_64')
url='https://github.com/BigPizzaV3/CodexPlusPlus'
license=('MIT')
options=('!lto')
depends=(
  'bash'
  'chatgpt'
  'procps-ng'
)
makedepends=(
  'cargo'
)
install="\${pkgname}.install"
source=(
  "\${pkgname}-\${pkgver}.tar.gz::https://github.com/BigPizzaV3/CodexPlusPlus/archive/refs/tags/v\${pkgver}.tar.gz"
  'codex-desktop-app-wrapper.sh'
  'codex-plus-plus.sh'
  "\${pkgname}-linux-port-fallback.patch"
  '90-codex-plus-plus-reapply.hook'
  'codex-plus-plus.desktop'
)
sha256sums=(
  '${source_sha256}'
  '${wrapper_sha256}'
  '${manager_sha256}'
  '${linux_port_patch_sha256}'
  '${hook_sha256}'
  '${desktop_sha256}'
)

prepare() {
  cd "\${srcdir}/CodexPlusPlus-\${pkgver}"
  patch -Np1 -i "\${srcdir}/\${pkgname}-linux-port-fallback.patch"
}

build() {
  cd "\${srcdir}/CodexPlusPlus-\${pkgver}"
  cargo build --release --locked -p codex-plus-launcher
}

package() {
  cd "\${srcdir}/CodexPlusPlus-\${pkgver}"

  install -dm755 \\
    "\${pkgdir}/usr/bin" \\
    "\${pkgdir}/usr/lib/\${pkgname}/app" \\
    "\${pkgdir}/usr/lib/\${pkgname}/bin" \\
    "\${pkgdir}/usr/lib/\${pkgname}/upstream" \\
    "\${pkgdir}/usr/share/applications" \\
    "\${pkgdir}/usr/share/doc/\${pkgname}" \\
    "\${pkgdir}/usr/share/libalpm/hooks" \\
    "\${pkgdir}/var/lib/\${pkgname}"

  install -Dm755 "\${srcdir}/codex-desktop-app-wrapper.sh" \\
    "\${pkgdir}/usr/lib/\${pkgname}/app/ChatGPT"
  ln -s ChatGPT "\${pkgdir}/usr/lib/\${pkgname}/app/Codex"
  ln -s ChatGPT "\${pkgdir}/usr/lib/\${pkgname}/app/codex"

  install -Dm755 "target/release/codex-plus-plus" \\
    "\${pkgdir}/usr/lib/\${pkgname}/bin/codex-plus-plus-upstream"
  install -Dm755 "\${srcdir}/codex-plus-plus.sh" \\
    "\${pkgdir}/usr/bin/codex-plus-plus"
  ln -s /usr/bin/codex-plus-plus \\
    "\${pkgdir}/usr/lib/\${pkgname}/bin/chatgpt-injected"
  ln -s chatgpt-injected \\
    "\${pkgdir}/usr/lib/\${pkgname}/bin/codex-desktop-injected"
  ln -s codex-plus-plus "\${pkgdir}/usr/bin/codexplusplus"

  install -Dm644 "\${srcdir}/90-codex-plus-plus-reapply.hook" \\
    "\${pkgdir}/usr/share/libalpm/hooks/90-codex-plus-plus-reapply.hook"
  install -Dm644 "\${srcdir}/codex-plus-plus.desktop" \\
    "\${pkgdir}/usr/share/applications/codex-plus-plus.desktop"
  install -Dm644 README.md \\
    "\${pkgdir}/usr/share/doc/\${pkgname}/README.md"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
