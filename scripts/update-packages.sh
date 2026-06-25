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
  reasonix-desktop-bin
)

if [[ "$#" -gt 0 ]]; then
  packages=("$@")
elif [[ -n "${PACKAGES:-}" ]]; then
  read -r -a packages <<<"${PACKAGES}"
else
  packages=("${DEFAULT_PACKAGES[@]}")
fi

failed_packages=()

for package in "${packages[@]}"; do
  package_dir="${REPO_ROOT}/packages/${package}"
  update_script="${package_dir}/update.sh"

  if [[ ! -x "${update_script}" ]]; then
    printf 'missing executable update script: %s\n' "${update_script}" >&2
    failed_packages+=("${package}")
    continue
  fi

  printf 'updating %s\n' "${package}"
  if ! "${update_script}"; then
    printf 'failed to update %s\n' "${package}" >&2
    failed_packages+=("${package}")
  fi
done

if [[ "${#failed_packages[@]}" -gt 0 ]]; then
  printf 'failed packages: %s\n' "${failed_packages[*]}" >&2
  exit 1
fi
