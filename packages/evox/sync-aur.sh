#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGNAME="${PKGNAME:-evox}"
AUR_REMOTE_URL="${AUR_REMOTE_URL:-ssh://aur@aur.archlinux.org/${PKGNAME}.git}"
AUR_SSH_KEY="${AUR_SSH_KEY:-${HOME}/.ssh/aur_actions}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ -f "${AUR_SSH_KEY}" && -z "${GIT_SSH_COMMAND:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${AUR_SSH_KEY} -o IdentitiesOnly=yes"
fi

if git ls-remote "${AUR_REMOTE_URL}" >/dev/null 2>&1; then
  git clone "${AUR_REMOTE_URL}" "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
else
  git init --initial-branch=master "${WORK_DIR}/${PKGNAME}" >/dev/null 2>&1
  git -C "${WORK_DIR}/${PKGNAME}" remote add origin "${AUR_REMOTE_URL}"
fi

install -Dm644 "${SCRIPT_DIR}/PKGBUILD" "${WORK_DIR}/${PKGNAME}/PKGBUILD"
install -Dm644 "${SCRIPT_DIR}/.SRCINFO" "${WORK_DIR}/${PKGNAME}/.SRCINFO"

# AUR 要求 .SRCINFO 引用的本地 source/install 文件都出现在仓库里
mapfile -t local_files < <(
  sed -n -E 's/^[[:space:]]*install = //p; s/^[[:space:]]*source(_[^[:space:]]*)? = //p' "${SCRIPT_DIR}/.SRCINFO" |
    while IFS= read -r entry; do
      [[ "${entry}" == *'::'* ]] && entry="${entry##*::}"
      [[ "${entry}" =~ ^[a-z]+:// ]] && continue
      printf '%s\n' "${entry}"
    done | sort -u
)

for file in "${local_files[@]}"; do
  install -Dm644 "${SCRIPT_DIR}/${file}" "${WORK_DIR}/${PKGNAME}/${file}"
done

# 删除 AUR 仓库里已不被 .SRCINFO 引用的旧文件
for tracked_file in $(git -C "${WORK_DIR}/${PKGNAME}" ls-files); do
  case "${tracked_file}" in
    PKGBUILD|.SRCINFO) continue ;;
  esac
  keep=0
  for file in "${local_files[@]}"; do
    if [[ "${tracked_file}" == "${file}" ]]; then
      keep=1
      break
    fi
  done
  if [[ "${keep}" -eq 0 ]]; then
    git -C "${WORK_DIR}/${PKGNAME}" rm -q "${tracked_file}"
  fi
done

if [[ -z "$(git -C "${WORK_DIR}/${PKGNAME}" status --short)" ]]; then
  printf 'no changes\n'
  exit 0
fi

pkgver="$(sed -n 's/^pkgver=//p' "${SCRIPT_DIR}/PKGBUILD")"

git -C "${WORK_DIR}/${PKGNAME}" add -A

if git -C "${WORK_DIR}/${PKGNAME}" rev-parse --verify HEAD >/dev/null 2>&1; then
  git -C "${WORK_DIR}/${PKGNAME}" commit \
    -m "Update to ${pkgver}" \
    -m "- Update ${PKGNAME} to ${pkgver}" >/dev/null 2>&1
else
  git -C "${WORK_DIR}/${PKGNAME}" commit \
    -m "Initial import: ${PKGNAME} ${pkgver}" \
    -m "- Add initial AUR packaging for ${PKGNAME} ${pkgver}" >/dev/null 2>&1
fi

git -C "${WORK_DIR}/${PKGNAME}" push origin master
