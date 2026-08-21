#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_PACKAGES=(
  rebased-bin
  rebased-zh-bin
  keyviz-zh
  emeditor-wine
  navicat17-premium-cs
  wuyou-docs
  wuyou-toolkit
  mind-elixir
  ccgui-bin
  codeg-bin
  codepilot-bin
  gooeypi-bin
  zcode
  mastergo
  pilauncher-bin
  minimax-hub
  reasonix-desktop-bin
  pi-agent-desktop-bin
  reeden
  alexandria-bin
  android-dex-bin
  so-novel-bin
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

reconcile_aur_files() {
  local aur_dir="$1"
  local package_dir="$2"
  local aur_file
  local tracked_file
  local -a aur_files
  local -A expected_aur_files=()

  mapfile -t aur_files < <(aur_files_for_package "${package_dir}" | sort -u)

  for aur_file in "${aur_files[@]}"; do
    expected_aur_files["${aur_file}"]=1

    if [[ ! -f "${package_dir}/${aur_file}" ]]; then
      printf 'missing package file: %s\n' "${package_dir}/${aur_file}" >&2
      return 1
    fi

    install -Dm644 "${package_dir}/${aur_file}" "${aur_dir}/${aur_file}"
  done

  while IFS= read -r tracked_file; do
    if [[ -z "${expected_aur_files[${tracked_file}]+x}" ]]; then
      git -C "${aur_dir}" rm -- "${tracked_file}" >/dev/null
    fi
  done < <(git -C "${aur_dir}" ls-files)
}

push_with_retry() {
  local aur_dir="$1"
  local branch="$2"
  local package_dir="$3"

  if git -C "${aur_dir}" push origin "${branch}"; then
    return 0
  fi

  git -C "${aur_dir}" fetch origin "${branch}"
  git -C "${aur_dir}" rebase "origin/${branch}"
  reconcile_aur_files "${aur_dir}" "${package_dir}"

  if [[ -n "$(git -C "${aur_dir}" status --short)" ]]; then
    git -C "${aur_dir}" add --all
    git -C "${aur_dir}" commit -m 'Reconcile package files' >/dev/null 2>&1
  fi

  git -C "${aur_dir}" push origin "${branch}"
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

  reconcile_aur_files "${aur_dir}" "${package_dir}"

  if [[ -z "$(git -C "${aur_dir}" status --short)" ]]; then
    printf 'no changes for %s\n' "${package}"
    continue
  fi

  pkgver="$(sed -n 's/^pkgver=//p' "${package_dir}/PKGBUILD" | head -n1)"
  pkgrel="$(sed -n 's/^pkgrel=//p' "${package_dir}/PKGBUILD" | head -n1)"

  git -C "${aur_dir}" add --all

  if git -C "${aur_dir}" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "${aur_dir}" commit -m "Update to ${pkgver}-${pkgrel}" >/dev/null 2>&1
  else
    git -C "${aur_dir}" commit -m "Initial import: ${package} ${pkgver}-${pkgrel}" >/dev/null 2>&1
  fi

  push_with_retry "${aur_dir}" master "${package_dir}"
done
