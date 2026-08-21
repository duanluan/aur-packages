#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/SSShooter/Mind-Elixir-Desktop-Release/releases/latest}"
RELEASE_LATEST_URL="${RELEASE_LATEST_URL:-https://github.com/SSShooter/Mind-Elixir-Desktop-Release/releases/latest}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg

sha256_for_asset() {
  local asset_url="$1"
  local asset_name="$2"
  local asset_digest="$3"
  local tmpdir
  local attempt

  if [[ -n "${asset_digest}" && "${asset_digest}" != "null" ]]; then
    printf '%s\n' "${asset_digest#sha256:}"
    return 0
  fi

  if [[ -f "${SCRIPT_DIR}/${asset_name}" ]]; then
    sha256sum "${SCRIPT_DIR}/${asset_name}" | awk '{print $1}'
    return 0
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  for attempt in 1 2 3 4 5; do
    if curl -fL --retry 3 --retry-all-errors -C - "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1; then
      sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}'
      return 0
    fi
  done

  printf 'failed to download asset after retries: %s\n' "${asset_name}" >&2
  return 1
}

current_pkgver=""
current_pkgrel=""
current_sha256=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_sha256="$(sed -n "s/^sha256sums=('\\([^']*\\)').*/\\1/p" "${PKGBUILD_PATH}" | head -n1)"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json=""
if release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"; then
  tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
  pkgver="${tag_name#app-v}"
  pkgver="${pkgver#v}"
  asset_name="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("Mind.Elixir_" + $version + "_amd64.deb"))][0].name')"
  asset_url="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("Mind.Elixir_" + $version + "_amd64.deb"))][0].browser_download_url')"
  asset_digest="$(printf '%s\n' "${release_json}" | jq -r --arg version "${pkgver}" '[.assets[] | select(.name == ("Mind.Elixir_" + $version + "_amd64.deb"))][0].digest')"
else
  latest_headers="$(curl -fsSLI "${RELEASE_LATEST_URL}")"
  tag_name="$(printf '%s\n' "${latest_headers}" | sed -nE 's|^[Ll]ocation: .*/releases/tag/([^[:space:]\r]+).*|\1|p' | tail -n1)"
  pkgver="${tag_name#app-v}"
  pkgver="${pkgver#v}"
  asset_name="Mind.Elixir_${pkgver}_amd64.deb"
  asset_url="https://github.com/SSShooter/Mind-Elixir-Desktop-Release/releases/download/${tag_name}/${asset_name}"
  asset_digest=""
fi

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "${tag_name}" ]]; then
  printf 'failed to resolve latest app tag\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 deb asset\n' >&2
  exit 1
fi

pkgbuild_asset_url="${asset_url/\/download\/${tag_name}\//\/download\/app-v\$\{pkgver\}\/}"
pkgbuild_asset_url="${pkgbuild_asset_url/${asset_name}/Mind.Elixir_\$\{pkgver\}_amd64.deb}"
asset_sha256="$(sha256_for_asset "${asset_url}" "${asset_name}" "${asset_digest}")"

if [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_sha256}" == "${asset_sha256}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=mind-elixir
_pkgname=mind-elixir
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='Lightweight privacy-focused mind mapping tool (prebuilt binary)'
arch=('x86_64')
url='https://app.mind-elixir.com/'
license=('NOASSERTION')
depends=('gtk3' 'hicolor-icon-theme' 'webkit2gtk-4.1')
provides=("mind-elixir-bin=\${pkgver}")
options=('!strip')
source=("Mind.Elixir_\${pkgver}_amd64.deb::${pkgbuild_asset_url}")
sha256sums=('${asset_sha256}')

package() {
  local _extractdir
  _extractdir="\$(mktemp -d)"
  trap 'rm -rf "\${_extractdir}"' EXIT

  bsdtar -C "\${_extractdir}" -xf "\${srcdir}/Mind.Elixir_\${pkgver}_amd64.deb"
  bsdtar -C "\${pkgdir}" -xf "\${_extractdir}/data.tar.gz"

  install -dm755 "\${pkgdir}/usr/lib/\${_pkgname}"
  mv "\${pkgdir}/usr/bin/MindElixir" "\${pkgdir}/usr/lib/\${_pkgname}/MindElixir"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/mind-elixir" <<'SCRIPT'
#!/bin/sh
export WEBKIT_DISABLE_DMABUF_RENDERER="\${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
exec /usr/lib/mind-elixir/MindElixir "\$@"
SCRIPT

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/MindElixir" <<'SCRIPT'
#!/bin/sh
exec /usr/bin/mind-elixir "\$@"
SCRIPT

  sed -i \\
    -e 's|^Exec=.*|Exec=mind-elixir %U|' \\
    -e 's|^Categories=.*|Categories=Office;Utility;|' \\
    "\${pkgdir}/usr/share/applications/Mind Elixir.desktop"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
