#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGNAME="${PKGNAME:-mastergo}"
AUR_REMOTE_URL="${AUR_REMOTE_URL:-ssh://aur@aur.archlinux.org/${PKGNAME}.git}"
AUR_SSH_KEY="${AUR_SSH_KEY:-${HOME}/.ssh/aur_actions}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command git
require_command install
require_command mktemp
require_command ssh

if [[ -f "${AUR_SSH_KEY}" && -z "${GIT_SSH_COMMAND:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${AUR_SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
fi

"${SCRIPT_DIR}/update.sh" >/dev/null

if git ls-remote "${AUR_REMOTE_URL}" >/dev/null 2>&1; then
  git clone "${AUR_REMOTE_URL}" "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
else
  git init --initial-branch=master "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
  git -C "${WORK_DIR}/${PKGNAME}" remote add origin "${AUR_REMOTE_URL}"
fi

aur_dir="${WORK_DIR}/${PKGNAME}"
aur_files=(PKGBUILD .SRCINFO mastergo.sh mastergo.desktop patch-linux-runtime.mjs)

for aur_file in "${aur_files[@]}"; do
  install -Dm644 "${SCRIPT_DIR}/${aur_file}" "${aur_dir}/${aur_file}"
done

if [[ -z "$(git -C "${aur_dir}" status --short -- "${aur_files[@]}")" ]]; then
  printf 'no changes\n'
  exit 0
fi

pkgver="$(sed -n 's/^pkgver=//p' "${SCRIPT_DIR}/PKGBUILD" | head -n1)"
pkgrel="$(sed -n 's/^pkgrel=//p' "${SCRIPT_DIR}/PKGBUILD" | head -n1)"

git -C "${aur_dir}" add "${aur_files[@]}"

if git -C "${aur_dir}" rev-parse --verify HEAD >/dev/null 2>&1; then
  git -C "${aur_dir}" commit -m "Update to ${pkgver}-${pkgrel}" >/dev/null 2>&1
else
  git -C "${aur_dir}" commit -m "Initial import: ${PKGNAME} ${pkgver}-${pkgrel}" >/dev/null 2>&1
fi

git -C "${aur_dir}" push origin master
