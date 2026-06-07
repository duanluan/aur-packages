#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGNAME="${PKGNAME:-emeditor-wine}"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

"${REPO_ROOT}/scripts/sync-aur-packages.sh" "${PKGNAME}"
