#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGNAME="${PKGNAME:-keyviz-zh-bin}"
AUR_REMOTE_URL="${AUR_REMOTE_URL:-ssh://aur@aur.archlinux.org/${PKGNAME}.git}"
AUR_SSH_KEY="${AUR_SSH_KEY:-/home/duanluan/.ssh/aur_actions}"
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

if [[ ! -f "${AUR_SSH_KEY}" ]]; then
  printf 'missing ssh key: %s\n' "${AUR_SSH_KEY}" >&2
  exit 1
fi

export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -i ${AUR_SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new}"

"${SCRIPT_DIR}/update.sh" >/dev/null

if git ls-remote "${AUR_REMOTE_URL}" >/dev/null 2>&1; then
  git clone "${AUR_REMOTE_URL}" "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
else
  git init --initial-branch=master "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
  git -C "${WORK_DIR}/${PKGNAME}" remote add origin "${AUR_REMOTE_URL}"
fi

install -Dm644 "${SCRIPT_DIR}/PKGBUILD" "${WORK_DIR}/${PKGNAME}/PKGBUILD"
install -Dm644 "${SCRIPT_DIR}/.SRCINFO" "${WORK_DIR}/${PKGNAME}/.SRCINFO"

if [[ -z "$(git -C "${WORK_DIR}/${PKGNAME}" status --short -- PKGBUILD .SRCINFO)" ]]; then
  printf 'no changes\n'
  exit 0
fi

pkgver="$(sed -n 's/^pkgver=//p' "${SCRIPT_DIR}/PKGBUILD")"
pkgrel="$(sed -n 's/^pkgrel=//p' "${SCRIPT_DIR}/PKGBUILD")"

git -C "${WORK_DIR}/${PKGNAME}" add PKGBUILD .SRCINFO

if git -C "${WORK_DIR}/${PKGNAME}" rev-parse --verify HEAD >/dev/null 2>&1; then
  git -C "${WORK_DIR}/${PKGNAME}" commit -m "Update to ${pkgver}-${pkgrel}" >/dev/null 2>&1
else
  git -C "${WORK_DIR}/${PKGNAME}" commit -m "Initial import: ${PKGNAME} ${pkgver}-${pkgrel}" >/dev/null 2>&1
fi

git -C "${WORK_DIR}/${PKGNAME}" push origin master
