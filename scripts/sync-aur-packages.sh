#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_PACKAGES=(
  rebased-bin
  keyviz-zh-bin
  emeditor-wine
  navicat17-premium-cs
  wuyou-docs-bin
  wuyou-toolkit-bin
  mind-elixir-bin
  ccgui-bin
  zcode-desktop-bin
  mastergo-desktop-bin
  pilauncher-bin
  minimax-hub-bin
  reasonix-desktop-deb
)

AUR_SSH_KEY="${AUR_SSH_KEY:-${HOME}/.ssh/aur_actions}"
AUR_REMOTE_BASE="${AUR_REMOTE_BASE:-ssh://aur@aur.archlinux.org}"
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

push_with_retry() {
  local aur_dir="$1"
  local branch="$2"

  if git -C "${aur_dir}" push origin "${branch}"; then
    return 0
  fi

  git -C "${aur_dir}" fetch origin "${branch}"
  git -C "${aur_dir}" rebase "origin/${branch}"
  git -C "${aur_dir}" push origin "${branch}"
}

aur_files_for_package() {
  local package_dir="$1"
  local srcinfo_path="${package_dir}/.SRCINFO"
  local aur_entry

  printf '%s\n' PKGBUILD .SRCINFO

  sed -n -E 's/^[[:space:]]*install = //p; s/^[[:space:]]*source(_[^[:space:]]*)? = //p' "${srcinfo_path}" |
    while IFS= read -r aur_entry; do
      [[ "${aur_entry}" == *'::'* ]] && aur_entry="${aur_entry##*::}"
      [[ "${aur_entry}" =~ ^[a-z]+:// ]] && continue
      printf '%s\n' "${aur_entry}"
    done
}

if [[ -f "${AUR_SSH_KEY}" && -z "${GIT_SSH_COMMAND:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${AUR_SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
fi

if [[ "$#" -gt 0 ]]; then
  packages=("$@")
elif [[ -n "${PACKAGES:-}" ]]; then
  read -r -a packages <<<"${PACKAGES}"
else
  packages=("${DEFAULT_PACKAGES[@]}")
fi

for package in "${packages[@]}"; do
  package_dir="${REPO_ROOT}/packages/${package}"
  remote_url="${AUR_REMOTE_BASE}/${package}.git"
  aur_dir="${WORK_DIR}/${package}"

  if [[ ! -f "${package_dir}/PKGBUILD" || ! -f "${package_dir}/.SRCINFO" ]]; then
    printf 'missing package files: %s\n' "${package}" >&2
    exit 1
  fi

  printf 'syncing %s\n' "${package}"

  if git ls-remote "${remote_url}" >/dev/null 2>&1; then
    git clone "${remote_url}" "${aur_dir}" >/dev/null 2>&1
  else
    git init --initial-branch=master "${aur_dir}" >/dev/null 2>&1
    git -C "${aur_dir}" remote add origin "${remote_url}"
  fi

  mapfile -t aur_files < <(aur_files_for_package "${package_dir}" | sort -u)

  for aur_file in "${aur_files[@]}"; do
    if [[ ! -f "${package_dir}/${aur_file}" ]]; then
      printf 'missing package file: %s/%s\n' "${package}" "${aur_file}" >&2
      exit 1
    fi

    install -Dm644 "${package_dir}/${aur_file}" "${aur_dir}/${aur_file}"
  done

  if [[ -z "$(git -C "${aur_dir}" status --short -- "${aur_files[@]}")" ]]; then
    printf 'no changes for %s\n' "${package}"
    continue
  fi

  pkgver="$(sed -n 's/^pkgver=//p' "${package_dir}/PKGBUILD" | head -n1)"
  pkgrel="$(sed -n 's/^pkgrel=//p' "${package_dir}/PKGBUILD" | head -n1)"

  git -C "${aur_dir}" add "${aur_files[@]}"

  if git -C "${aur_dir}" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "${aur_dir}" commit -m "Update to ${pkgver}-${pkgrel}" >/dev/null 2>&1
  else
    git -C "${aur_dir}" commit -m "Initial import: ${package} ${pkgver}-${pkgrel}" >/dev/null 2>&1
  fi

  push_with_retry "${aur_dir}" master
done
