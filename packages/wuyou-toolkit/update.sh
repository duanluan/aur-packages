#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
RELEASE_API_URL="${RELEASE_API_URL:-https://api.github.com/repos/duanluan/wuyou-toolkit-releases/releases?per_page=100}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command makepkg

curl_headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${curl_headers[@]}" "${RELEASE_API_URL}")"
if ! IFS=$'\t' read -r tag_name pkgver asset_name asset_url asset_digest arm_asset_name arm_asset_url arm_asset_digest < <(
  printf '%s\n' "${release_json}" | jq -r '
    def releases: if type == "array" then . else [.] end;

    (releases
      | map({
          tag_name,
          asset: (
            .assets // []
            | map(select(.name | test("^wuyou-toolkit_[^/]+_amd64\\.deb$")))
            | .[0]
          ),
          arm_asset: (
            .assets // []
            | map(select(.name | test("^wuyou-toolkit_[^/]+_arm64\\.deb$")))
            | .[0]
          )
        })
      | map(select(.asset != null))
      | .[0]) as $release
    | if $release == null then
        empty
      else
        ($release.asset.name | capture("^wuyou-toolkit_(?<version>.+)_amd64\\.deb$").version) as $version
        | [
            ($release.tag_name // ""),
            $version,
            ($release.asset.name // ""),
            ($release.asset.browser_download_url // ""),
            ($release.asset.digest // ""),
            ($release.arm_asset.name // ""),
            ($release.arm_asset.browser_download_url // ""),
            ($release.arm_asset.digest // "")
          ]
        | @tsv
      end
  '
); then
  tag_name=""
  pkgver=""
  asset_name=""
  asset_url=""
  asset_digest=""
  arm_asset_name=""
  arm_asset_url=""
  arm_asset_digest=""
fi

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${pkgver}" ]]; then
  printf 'failed to resolve release with amd64 deb asset\n' >&2
  exit 1
fi

if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  printf 'failed to resolve amd64 deb asset\n' >&2
  exit 1
fi

if [[ -z "${arm_asset_name}" || "${arm_asset_name}" == "null" || -z "${arm_asset_url}" || "${arm_asset_url}" == "null" ]]; then
  printf 'failed to resolve arm64 deb asset\n' >&2
  exit 1
fi

pkgbuild_asset_url="${asset_url/\/download\/${tag_name}\//\/download\/v\$\{pkgver\}\/}"
pkgbuild_asset_url="${pkgbuild_asset_url/${asset_name}/\$\{_pkgname\}_\$\{pkgver\}_amd64.deb}"
pkgbuild_arm_asset_url="${arm_asset_url/\/download\/${tag_name}\//\/download\/v\$\{pkgver\}\/}"
pkgbuild_arm_asset_url="${pkgbuild_arm_asset_url/${arm_asset_name}/\$\{_pkgname\}_\$\{pkgver\}_arm64.deb}"
if [[ -n "${asset_digest}" && "${asset_digest}" != "null" ]]; then
  asset_sha256="${asset_digest#sha256:}"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL "${asset_url}" -o "${tmpdir}/${asset_name}" >/dev/null 2>&1
  asset_sha256="$(sha256sum "${tmpdir}/${asset_name}" | awk '{print $1}')"
fi
if [[ -n "${arm_asset_digest}" && "${arm_asset_digest}" != "null" ]]; then
  arm_asset_sha256="${arm_asset_digest#sha256:}"
else
  tmpdir="${tmpdir:-$(mktemp -d)}"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL "${arm_asset_url}" -o "${tmpdir}/${arm_asset_name}" >/dev/null 2>&1
  arm_asset_sha256="$(sha256sum "${tmpdir}/${arm_asset_name}" | awk '{print $1}')"
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=wuyou-toolkit
_pkgname=wuyou-toolkit
pkgver=${pkgver}
pkgrel=1
pkgdesc='Native shell for wuyou-toolkit (prebuilt binary)'
arch=('x86_64' 'aarch64')
url='https://github.com/duanluan/wuyou-toolkit-releases'
license=('NOASSERTION')
depends=('gtk3' 'webkit2gtk-4.1')
provides=("wuyou-toolkit-bin=\${pkgver}")
options=('!strip')
source_x86_64=("\${_pkgname}_\${pkgver}_amd64.deb::${pkgbuild_asset_url}")
source_aarch64=("\${_pkgname}_\${pkgver}_arm64.deb::${pkgbuild_arm_asset_url}")
sha256sums_x86_64=('${asset_sha256}')
sha256sums_aarch64=('${arm_asset_sha256}')

package() {
  local _deb_arch _extractdir
  _extractdir="\$(mktemp -d)"
  trap 'rm -rf "\${_extractdir}"' EXIT

  case "\${CARCH}" in
    x86_64) _deb_arch='amd64' ;;
    aarch64) _deb_arch='arm64' ;;
  esac

  bsdtar -C "\${_extractdir}" -xf "\${srcdir}/\${_pkgname}_\${pkgver}_\${_deb_arch}.deb"
  bsdtar -C "\${pkgdir}" -xf "\${_extractdir}/data.tar.gz"

  sed -i \
    -e 's/^Name=.*/Name=Wuyou Toolkit/' \
    -e 's/^Comment=.*/Comment=Cross-platform desktop toolbox/' \
    -e 's/^Categories=.*/Categories=Utility;Development;/' \
    "\${pkgdir}/usr/share/applications/wuyou-toolkit.desktop"
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
