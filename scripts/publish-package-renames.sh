#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if ! command -v rg >/dev/null 2>&1; then
  printf 'missing dependency: rg\n' >&2
  exit 1
fi

package_renames=(
  'keyviz-zh-bin:keyviz-zh'
  'mastergo-desktop-bin:mastergo'
  'minimax-hub-bin:minimax-hub'
  'mind-elixir-bin:mind-elixir'
  'reeden-bin:reeden'
  'wuyou-docs-bin:wuyou-docs'
  'wuyou-toolkit-bin:wuyou-toolkit'
  'zcode-desktop-bin:zcode'
)

canonical_packages=()
transitional_packages=()

for package_rename in "${package_renames[@]}"; do
  transitional_package="${package_rename%%:*}"
  canonical_package="${package_rename#*:}"
  transitional_srcinfo="${REPO_ROOT}/packages/${transitional_package}/.SRCINFO"
  canonical_srcinfo="${REPO_ROOT}/packages/${canonical_package}/.SRCINFO"

  if [[ ! -f "${transitional_srcinfo}" || ! -f "${canonical_srcinfo}" ]]; then
    printf 'missing package metadata for rename: %s -> %s\n' \
      "${transitional_package}" "${canonical_package}" >&2
    exit 1
  fi

  if ! rg -q "^[[:space:]]+depends = ${canonical_package}>=" \
    "${transitional_srcinfo}"; then
    printf 'missing transition dependency: %s -> %s\n' \
      "${transitional_package}" "${canonical_package}" >&2
    exit 1
  fi

  if ! rg -q "^[[:space:]]+provides = ${transitional_package}=" \
    "${canonical_srcinfo}"; then
    printf 'missing compatibility declaration: %s -> %s\n' \
      "${canonical_package}" "${transitional_package}" >&2
    exit 1
  fi

  canonical_packages+=("${canonical_package}")
  transitional_packages+=("${transitional_package}")
done

"${SCRIPT_DIR}/sync-aur-packages.sh" "${canonical_packages[@]}"
"${SCRIPT_DIR}/sync-aur-packages.sh" "${transitional_packages[@]}"
