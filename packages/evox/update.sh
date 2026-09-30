#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
MANIFEST_URL="${EVOX_MANIFEST_URL:-https://res.evomap.ai/downloads/evox-linux/beta/manifest.json}"

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

current_pkgver=""
current_pkgrel=""
current_sha256_x86_64=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_pkgrel="$(awk -F= '/^pkgrel=/ {print $2; exit}' "${PKGBUILD_PATH}")"
  current_sha256_x86_64="$(awk -F"'" '/^sha256sums_x86_64=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

manifest="$(curl -fsSL --retry 5 --retry-all-errors "${MANIFEST_URL}")"

upstream_ver="$(printf '%s\n' "${manifest}" | jq -r '.cli.version // empty')"
if [[ -z "${upstream_ver}" || "${upstream_ver}" == "null" ]]; then
  printf 'failed to read version from manifest: %s\n' "${MANIFEST_URL}" >&2
  exit 1
fi

# makepkg forbids hyphens in pkgver
pkgver="${upstream_ver//-/.}"

fetch_asset_field() {
  local triple="$1" field="$2"
  printf '%s\n' "${manifest}" | jq -r --arg t "${triple}" --arg f "${field}" \
    '.cli.assets[$t][$f] // empty'
}

asset_x86_64_url="$(fetch_asset_field x86_64-unknown-linux-gnu url)"
asset_x86_64_sha256="$(fetch_asset_field x86_64-unknown-linux-gnu sha256)"
asset_aarch64_url="$(fetch_asset_field aarch64-unknown-linux-gnu url)"
asset_aarch64_sha256="$(fetch_asset_field aarch64-unknown-linux-gnu sha256)"

for var_name in asset_x86_64_url asset_x86_64_sha256 asset_aarch64_url asset_aarch64_sha256; do
  if [[ -z "${!var_name}" || "${!var_name}" == "null" ]]; then
    printf 'manifest is missing %s\n' "${var_name}" >&2
    exit 1
  fi
done

if [[ "${current_pkgver}" == "${pkgver}" &&
      "${current_pkgrel}" =~ ^[0-9]+$ &&
      "${current_sha256_x86_64}" == "${asset_x86_64_sha256}" ]]; then
  pkgrel="${current_pkgrel}"
elif [[ "${current_pkgver}" == "${pkgver}" && "${current_pkgrel}" =~ ^[0-9]+$ ]]; then
  pkgrel="$((current_pkgrel + 1))"
else
  pkgrel=1
fi

cat > "${PKGBUILD_PATH}" <<EOF
# Maintainer: duanluan <duanluan@outlook.com>

pkgname=evox
_pkgname=evox
pkgver=${pkgver}
pkgrel=${pkgrel}
_upstream_ver=${upstream_ver}
pkgdesc='EvoMap EvoX self-evolving swarm coding agent (beta channel)'
arch=('x86_64' 'aarch64')
url='https://evomap.ai/zh/evox/beta'
license=('LicenseRef-Proprietary')
depends=('glibc')
options=('!strip')
source_x86_64=("\${_pkgname}-linux-v\${_upstream_ver}-x86_64-unknown-linux-gnu.tar.gz::${asset_x86_64_url}")
source_aarch64=("\${_pkgname}-linux-v\${_upstream_ver}-aarch64-unknown-linux-gnu.tar.gz::${asset_aarch64_url}")
sha256sums_x86_64=('${asset_x86_64_sha256}')
sha256sums_aarch64=('${asset_aarch64_sha256}')

package() {
  local bundle_dir

  case "\${CARCH}" in
    x86_64)
      bundle_dir="\${srcdir}/\${_pkgname}-linux-v\${_upstream_ver}-x86_64-unknown-linux-gnu"
      ;;
    aarch64)
      bundle_dir="\${srcdir}/\${_pkgname}-linux-v\${_upstream_ver}-aarch64-unknown-linux-gnu"
      ;;
    *)
      printf 'unsupported architecture: %s\n' "\${CARCH}" >&2
      return 1
      ;;
  esac

  # The release archive is an installer transport, not a runnable layout:
  # the binary reads its release-bound entitlement from <agent-dir> and
  # never looks next to itself, so keep the payload under /usr/lib and let
  # the /usr/bin launcher provision ~/.evox/agent per user.
  install -Dm755 "\${bundle_dir}/evox" "\${pkgdir}/usr/lib/\${_pkgname}/evox"
  install -Dm644 "\${bundle_dir}/entitlement.json" "\${pkgdir}/usr/lib/\${_pkgname}/entitlement.json"
  install -dm755 "\${pkgdir}/usr/lib/\${_pkgname}/extensions"
  install -m644 "\${bundle_dir}/extensions/"* "\${pkgdir}/usr/lib/\${_pkgname}/extensions/"
  printf '%s\n' "\${pkgver}" > "\${pkgdir}/usr/lib/\${_pkgname}/version"

  install -Dm755 /dev/stdin "\${pkgdir}/usr/bin/\${_pkgname}" <<'SCRIPT'
#!/bin/sh
# evox package launcher: provisions the per-user EvoX agent directory
# (~/.evox/agent by default) with the packaged entitlement and signed
# extensions, then execs the pacman-managed binary.
set -eu

lib_dir=/usr/lib/evox
packaged_version="\$(cat "\${lib_dir}/version" 2>/dev/null || printf 'unknown')"

agent_dir="\${EVOX_CODING_AGENT_DIR:-\${EVOX_AGENT_DIR:-\${HOME}/.evox/agent}}"
case "\${agent_dir}" in
  '~') agent_dir="\${HOME}" ;;
  '~/'*) agent_dir="\${HOME}/\${agent_dir#~/}" ;;
esac

stamp_file="\${agent_dir}/.evox-stamp"

if [ "\$(cat "\${stamp_file}" 2>/dev/null)" != "\${packaged_version}" ]; then
  mkdir -p "\${agent_dir}/extensions"

  # drop extensions copied from an older packaged release
  for f in "\${agent_dir}/extensions"/libevox_ext_*.so \\
           "\${agent_dir}/extensions"/libevox_ext_*.so.sig; do
    if [ -e "\${f}" ]; then
      rm -f "\${f}"
    fi
  done

  # install this release's signed extensions
  for f in "\${lib_dir}/extensions"/libevox_ext_*.so; do
    if [ -e "\${f}" ]; then
      name="\${f##*/}"
      install -m 0644 "\${f}" "\${agent_dir}/extensions/\${name}"
      if [ -e "\${f}.sig" ]; then
        install -m 0644 "\${f}.sig" "\${agent_dir}/extensions/\${name}.sig"
      fi
    fi
  done

  # the entitlement is release-bound; upstream installs it 0600
  install -m 0600 "\${lib_dir}/entitlement.json" "\${agent_dir}/entitlement.json"
  printf '%s\n' "\${packaged_version}" > "\${stamp_file}"
fi

exec "\${lib_dir}/evox" "\$@"
SCRIPT
}
EOF

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
