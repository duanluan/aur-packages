set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
BASE_URL="${BASE_URL:-https://filecdn.minimax.chat/public/minimax-hub/release/domestic}"

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

curl_retry() {
  curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 6 \
    --retry-delay 5 \
    --retry-max-time 180 \
    --retry-connrefused \
    --retry-all-errors \
    --connect-timeout 20 \
    "$@"
}

latest_mac_yml="$(curl_retry "${BASE_URL}/latest-mac.yml")"
pkgver="$(printf '%s\n' "${latest_mac_yml}" | awk '/^version:/ {print $2; exit}')"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest MiniMax Hub macOS version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

x64_url="${BASE_URL}/MiniMax%20Hub-${pkgver}.dmg"
arm64_url="${BASE_URL}/MiniMax%20Hub-${pkgver}-arm64.dmg"

curl_retry --output "${tmpdir}/MiniMax-Hub-${pkgver}-mac-x64.dmg" "${x64_url}" >/dev/null
curl_retry --output "${tmpdir}/MiniMax-Hub-${pkgver}-mac-arm64.dmg" "${arm64_url}" >/dev/null

x64_sha256="$(sha256sum "${tmpdir}/MiniMax-Hub-${pkgver}-mac-x64.dmg" | awk '{print $1}')"
arm64_sha256="$(sha256sum "${tmpdir}/MiniMax-Hub-${pkgver}-mac-arm64.dmg" | awk '{print $1}')"

sed -i -E \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "/^sha256sums_x86_64=\\('/s/'[0-9a-f]{64}'/'${x64_sha256}'/" \
  -e "/^sha256sums_aarch64=\\('/s/'[0-9a-f]{64}'/'${arm64_sha256}'/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
