#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_PACKAGES=(
  rebased-bin
  keyviz-zh-bin
  navicat17-premium-cs
  wuyou-docs-bin
  wuyou-toolkit-bin
  mind-elixir-bin
  ccgui-bin
  codex-plus-plus
)

if [[ "$#" -gt 0 ]]; then
  packages=("$@")
elif [[ -n "${PACKAGES:-}" ]]; then
  read -r -a packages <<<"${PACKAGES}"
else
  packages=("${DEFAULT_PACKAGES[@]}")
fi

for package in "${packages[@]}"; do
  package_dir="${REPO_ROOT}/packages/${package}"
  update_script="${package_dir}/update.sh"

  if [[ ! -x "${update_script}" ]]; then
    printf 'missing executable update script: %s\n' "${update_script}" >&2
    exit 1
  fi

  printf 'updating %s\n' "${package}"
  "${update_script}"
done
