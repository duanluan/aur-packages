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

release_url_from_latest_mac_yml() {
  local arch="$1"

  printf '%s\n' "${latest_mac_yml}" | awk -v arch="${arch}" '
    /^[[:space:]]*-[[:space:]]*url:[[:space:]]*/ {
      url = $0
      sub(/^[[:space:]]*-[[:space:]]*url:[[:space:]]*/, "", url)

      if (arch == "x64" && url ~ /-mac\.zip$/ && url !~ /arm64/) {
        print url
        exit
      }

      if (arch == "arm64" && url ~ /-arm64-mac\.zip$/) {
        print url
        exit
      }
    }
  '
}

resolve_release_url() {
  local release_path="$1"
  local encoded_path="${release_path// /%20}"

  if [[ "${encoded_path}" == http://* || "${encoded_path}" == https://* ]]; then
    printf '%s\n' "${encoded_path}"
    return
  fi

  printf '%s/%s\n' "${BASE_URL%/}" "${encoded_path#/}"
}

latest_mac_yml="$(curl_retry "${BASE_URL}/latest-mac.yml")"
pkgver="$(printf '%s\n' "${latest_mac_yml}" | awk '/^version:/ {print $2; exit}')"

if [[ -z "${pkgver}" ]]; then
  printf 'failed to resolve latest MiniMax Hub macOS version\n' >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

x64_release_path="$(release_url_from_latest_mac_yml x64)"
arm64_release_path="$(release_url_from_latest_mac_yml arm64)"

if [[ -z "${x64_release_path}" || -z "${arm64_release_path}" ]]; then
  printf 'failed to resolve MiniMax Hub macOS download urls from latest-mac.yml\n' >&2
  exit 1
fi

x64_url="$(resolve_release_url "${x64_release_path}")"
arm64_url="$(resolve_release_url "${arm64_release_path}")"

x64_archive="MiniMax-Hub-${pkgver}-mac-x64.zip"
arm64_archive="MiniMax-Hub-${pkgver}-mac-arm64.zip"

curl_retry --output "${tmpdir}/${x64_archive}" "${x64_url}" >/dev/null
curl_retry --output "${tmpdir}/${arm64_archive}" "${arm64_url}" >/dev/null

x64_sha256="$(sha256sum "${tmpdir}/${x64_archive}" | awk '{print $1}')"
arm64_sha256="$(sha256sum "${tmpdir}/${arm64_archive}" | awk '{print $1}')"

awk \
  -v pkgver="${pkgver}" \
  -v x64_url="${x64_url}" \
  -v arm64_url="${arm64_url}" \
  -v x64_sha256="${x64_sha256}" \
  -v arm64_sha256="${arm64_sha256}" '
    /^pkgver=/ {
      print "pkgver=" pkgver
      next
    }

    /^[[:space:]]*"MiniMax-Hub-\$\{pkgver\}-mac-x64\.(dmg|zip)::/ {
      print "  \"MiniMax-Hub-${pkgver}-mac-x64.zip::" x64_url "\""
      next
    }

    /^[[:space:]]*"MiniMax-Hub-\$\{pkgver\}-mac-arm64\.(dmg|zip)::/ {
      print "  \"MiniMax-Hub-${pkgver}-mac-arm64.zip::" arm64_url "\""
      next
    }

    /^[[:space:]]*"MiniMax-Hub-\$\{pkgver\}-mac-x64\.(dmg|zip)"$/ {
      print "  \"MiniMax-Hub-${pkgver}-mac-x64.zip\""
      next
    }

    /^[[:space:]]*"MiniMax-Hub-\$\{pkgver\}-mac-arm64\.(dmg|zip)"$/ {
      print "  \"MiniMax-Hub-${pkgver}-mac-arm64.zip\""
      next
    }

    /^sha256sums_x86_64=\('\''[0-9a-f]{64}'\''\)/ {
      print "sha256sums_x86_64=(\047" x64_sha256 "\047)"
      next
    }

    /^sha256sums_aarch64=\('\''[0-9a-f]{64}'\''\)/ {
      print "sha256sums_aarch64=(\047" arm64_sha256 "\047)"
      next
    }

    { print }
  ' "${PKGBUILD_PATH}" > "${tmpdir}/PKGBUILD"
mv "${tmpdir}/PKGBUILD" "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf '%s\n' "${pkgver}"
