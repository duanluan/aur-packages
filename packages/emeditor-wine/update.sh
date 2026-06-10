#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
REPO_API_URL="${REPO_API_URL:-https://api.github.com/repos/duanluan/emeditor-linux}"
RELEASE_API_URL="${RELEASE_API_URL:-${REPO_API_URL}/releases/latest}"
EMEDITOR_DOWNLOAD_BASE="${EMEDITOR_DOWNLOAD_BASE:-https://download.emeditor.com}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

sha256_for_url() {
  local asset_url="$1"
  local asset_name="$2"
  local tmpdir
  local attempt

  tmpdir="$(mktemp -d)"

  for attempt in 1 2 3 4 5; do
    if curl -fL --retry 3 --retry-all-errors "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1; then
      sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}'
      rm -rf "${tmpdir}"
      return 0
    fi
  done

  rm -rf "${tmpdir}"
  printf 'failed to download asset after retries: %s\n' "${asset_name}" >&2
  return 1
}

sha256_for_msi() {
  local msi_url="$1"
  local msi_name="$2"
  local headers
  local header_sha256

  if headers="$(curl -fsSLI --retry 3 --retry-all-errors "${msi_url}")"; then
    header_sha256="$(
      printf '%s\n' "${headers}" |
        awk 'BEGIN { IGNORECASE = 1 } /^x-ms-meta-sha256:/ { gsub("\r", ""); print tolower($2); exit }'
    )"

    if [[ "${header_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
      printf '%s\n' "${header_sha256}"
      return 0
    fi
  fi

  sha256_for_url "${msi_url}" "${msi_name}"
}

resolve_tag_commit() {
  local tag_name="$1"
  local ref_json
  local object_sha
  local object_type
  local tag_json

  ref_json="$(curl -fsSL "${curl_headers[@]}" "${REPO_API_URL}/git/ref/tags/${tag_name}")"
  object_sha="$(printf '%s\n' "${ref_json}" | jq -r '.object.sha')"
  object_type="$(printf '%s\n' "${ref_json}" | jq -r '.object.type')"

  if [[ "${object_type}" == "tag" ]]; then
    tag_json="$(curl -fsSL "${curl_headers[@]}" "${REPO_API_URL}/git/tags/${object_sha}")"
    object_sha="$(printf '%s\n' "${tag_json}" | jq -r '.object.sha')"
    object_type="$(printf '%s\n' "${tag_json}" | jq -r '.object.type')"
  fi

  if [[ -z "${object_sha}" || "${object_sha}" == "null" || "${object_type}" != "commit" ]]; then
    printf 'failed to resolve commit for tag: %s\n' "${tag_name}" >&2
    return 1
  fi

  printf '%s\n' "${object_sha}"
}

require_command awk
require_command curl
require_command jq
require_command makepkg
require_command sed
require_command sha256sum

current_pkgver=""
current_pkgrel=""
current_commit=""
current_source_sha256=""
current_msi_sha256=""

if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(sed -n 's/^pkgver=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_pkgrel="$(sed -n 's/^pkgrel=//p' "${PKGBUILD_PATH}" | head -n1)"
  current_commit="$(sed -n -E "s/^_commit=['\"]?([^'\"]+)['\"]?$/\1/p" "${PKGBUILD_PATH}" | head -n1)"
  mapfile -t current_sha256s < <(
    sed -n -E "s/.*'([0-9a-fA-F]{64})'.*/\1/p" "${PKGBUILD_PATH}" |
      tr '[:upper:]' '[:lower:]'
  )
  current_source_sha256="${current_sha256s[0]:-}"
  current_msi_sha256="${current_sha256s[1]:-}"
fi

curl_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"
tag_name="$(printf '%s\n' "${release_json}" | jq -r '.tag_name')"
pkgver="${tag_name#v}"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  printf 'failed to resolve latest release tag\n' >&2
  exit 1
fi

if [[ ! "${pkgver}" =~ ^[0-9]+([.][0-9]+)+$ ]]; then
  printf 'unexpected release tag format: %s\n' "${tag_name}" >&2
  exit 1
fi

version_regex="${pkgver//./\\.}"
release_pkgrel="$(
  printf '%s\n' "${release_json}" |
    jq -r '.assets[]?.name' |
    sed -n -E \
      -e "s/^EmEditor-Wine-${version_regex}-([0-9]+)-x86_64[.]AppImage$/\1/p" \
      -e "s/^emeditor-wine_${version_regex}-([0-9]+)_amd64[.]deb$/\1/p" \
      -e "s/^emeditor-wine-${version_regex}-([0-9]+)[.][^.]+[.]noarch[.]rpm$/\1/p" |
    head -n1
)"

commit="$(resolve_tag_commit "${tag_name}")"
source_name="emeditor-linux-${commit}.tar.gz"
source_url="https://github.com/duanluan/emeditor-linux/archive/${commit}.tar.gz"
msi_name="emed64_${pkgver}.msi"
msi_url="${EMEDITOR_DOWNLOAD_BASE}/${msi_name}"

source_sha256="$(sha256_for_url "${source_url}" "${source_name}")"
msi_sha256="$(sha256_for_msi "${msi_url}" "${msi_name}")"

if [[ -n "${release_pkgrel}" && "${release_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="${release_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  if [[ "${current_commit}" == "${commit}" && "${current_source_sha256}" == "${source_sha256}" && "${current_msi_sha256}" == "${msi_sha256}" ]]; then
    pkgrel="${current_pkgrel}"
  else
    pkgrel="$((current_pkgrel + 1))"
  fi
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=emeditor-wine
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc='EmEditor text editor running through Wine'
arch=('x86_64')
url='https://github.com/duanluan/emeditor-linux'
license=('MIT' 'custom:proprietary')
depends=(
  'bash'
  'curl'
  'hicolor-icon-theme'
  'noto-fonts-cjk'
  'wine'
  'xorg-xrandr'
  'xorg-xrdb'
)
makedepends=(
  '7zip'
)
optdepends=(
  'winetricks: optional Wine prefix tuning'
)
options=('!strip')
_commit='${commit}'
_upstream="emeditor-linux-\${_commit}"
_msi="emed64_\${pkgver}.msi"
source=(
  "\${_upstream}.tar.gz::https://github.com/duanluan/emeditor-linux/archive/\${_commit}.tar.gz"
  "\${_msi}::${EMEDITOR_DOWNLOAD_BASE}/\${_msi}"
)
sha256sums=(
  '${source_sha256}'
  '${msi_sha256}'
)

package() {
  local upstream_dir="\${srcdir}/\${_upstream}"

  7z e -y "\${srcdir}/\${_msi}" 'Binary.emeditor.targetsize256.png' \\
    -o"\${srcdir}" >/dev/null

  install -Dm755 "\${upstream_dir}/scripts/emeditor-wine" \\
    "\${pkgdir}/usr/bin/emeditor-wine"
  install -Dm644 "\${upstream_dir}/assets/emeditor-wine.desktop" \\
    "\${pkgdir}/usr/share/applications/emeditor-wine.desktop"
  install -Dm644 "\${srcdir}/\${_msi}" \\
    "\${pkgdir}/usr/share/\${pkgname}/\${_msi}"
  install -Dm644 "\${srcdir}/Binary.emeditor.targetsize256.png" \\
    "\${pkgdir}/usr/share/icons/hicolor/256x256/apps/emeditor-wine.png"
  install -Dm644 "\${upstream_dir}/LICENSE" \\
    "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
  install -Dm644 "\${upstream_dir}/README.md" \\
    "\${pkgdir}/usr/share/doc/\${pkgname}/README.md"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s-%s\n' "${pkgver}" "${pkgrel}"
