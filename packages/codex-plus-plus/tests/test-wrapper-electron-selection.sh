#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
WRAPPER="${PACKAGE_DIR}/codex-desktop-app-wrapper.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

free_port() {
  python - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

make_fake_electron() {
  local path="$1"

  install -dm755 "$(dirname -- "${path}")"
  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0" > "${CODEXPP_TEST_INVOKED_ELECTRON}"
exit 0
EOF
  chmod +x "${path}"
}

setup_app() {
  local tmpdir="$1"

  install -dm755 \
    "${tmpdir}/app/resources" \
    "${tmpdir}/app/content/webview/assets"
  touch "${tmpdir}/app/resources/app.asar"
  printf 'console.log("plugin auth unlocked");\n' >"${tmpdir}/plugin-auth-unlocked.js"
  printf 'console.log("original plugin auth");\n' >"${tmpdir}/app/content/webview/assets/plugin-auth-test.js"
}

run_wrapper() {
  local tmpdir="$1"
  local port

  port="$(free_port)"
  CODEXPP_OPENAI_CODEX_APP_DIR="${tmpdir}/app" \
    CODEXPP_OPENAI_CODEX_LAUNCHER="${tmpdir}/codex-desktop" \
    CODEXPP_PLUGIN_AUTH_UNLOCK_FILE="${tmpdir}/plugin-auth-unlocked.js" \
    CODEXPP_RENDERER_PORT="${port}" \
    CODEXPP_TEST_INVOKED_ELECTRON="${tmpdir}/invoked-electron" \
    "${WRAPPER}" >/dev/null 2>&1
}

run_wrapper_with_electron_config() {
  local tmpdir="$1"
  local config_file="$2"
  local port

  port="$(free_port)"
  CODEXPP_OPENAI_CODEX_APP_DIR="${tmpdir}/app" \
    CODEXPP_OPENAI_CODEX_LAUNCHER="${tmpdir}/codex-desktop" \
    CODEXPP_OPENAI_CODEX_ELECTRON_CONFIG="${config_file}" \
    CODEXPP_PLUGIN_AUTH_UNLOCK_FILE="${tmpdir}/plugin-auth-unlocked.js" \
    CODEXPP_RENDERER_PORT="${port}" \
    CODEXPP_TEST_INVOKED_ELECTRON="${tmpdir}/invoked-electron" \
    "${WRAPPER}" >/dev/null 2>&1
}

test_prefers_upstream_launcher_electron_over_appdir_codex() {
  local tmpdir
  local expected
  local actual

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  setup_app "${tmpdir}"
  make_fake_electron "${tmpdir}/electron39/electron"
  make_fake_electron "${tmpdir}/electron41/electron"
  install -Dm755 "${tmpdir}/electron41/electron" "${tmpdir}/app/codex"

  cat >"${tmpdir}/codex-desktop" <<EOF
#!/usr/bin/env bash
electron="${tmpdir}/electron39/electron"
"\${electron}" "\$@"
EOF
  chmod +x "${tmpdir}/codex-desktop"

  run_wrapper "${tmpdir}"

  expected="${tmpdir}/electron39/electron"
  actual="$(cat "${tmpdir}/invoked-electron")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "expected upstream launcher electron ${expected}, got ${actual}"
}

test_explicit_electron_env_wins() {
  local tmpdir
  local expected
  local actual
  local port

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  setup_app "${tmpdir}"
  make_fake_electron "${tmpdir}/electron39/electron"
  make_fake_electron "${tmpdir}/electron41/electron"
  make_fake_electron "${tmpdir}/override/electron"
  install -Dm755 "${tmpdir}/electron41/electron" "${tmpdir}/app/codex"

  cat >"${tmpdir}/codex-desktop" <<EOF
#!/usr/bin/env bash
electron="${tmpdir}/electron39/electron"
"\${electron}" "\$@"
EOF
  chmod +x "${tmpdir}/codex-desktop"

  port="$(free_port)"
  CODEXPP_OPENAI_CODEX_APP_DIR="${tmpdir}/app" \
    CODEXPP_OPENAI_CODEX_LAUNCHER="${tmpdir}/codex-desktop" \
    CODEXPP_OPENAI_CODEX_ELECTRON="${tmpdir}/override/electron" \
    CODEXPP_PLUGIN_AUTH_UNLOCK_FILE="${tmpdir}/plugin-auth-unlocked.js" \
    CODEXPP_RENDERER_PORT="${port}" \
    CODEXPP_TEST_INVOKED_ELECTRON="${tmpdir}/invoked-electron" \
    "${WRAPPER}" >/dev/null 2>&1

  expected="${tmpdir}/override/electron"
  actual="$(cat "${tmpdir}/invoked-electron")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "expected override electron ${expected}, got ${actual}"
}

test_electron_config_file_wins_over_upstream_launcher() {
  local tmpdir
  local expected
  local actual
  local config_file

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  setup_app "${tmpdir}"
  make_fake_electron "${tmpdir}/electron39/electron"
  make_fake_electron "${tmpdir}/electron41/electron"
  make_fake_electron "${tmpdir}/manual/electron"
  install -Dm755 "${tmpdir}/electron41/electron" "${tmpdir}/app/codex"

  cat >"${tmpdir}/codex-desktop" <<EOF
#!/usr/bin/env bash
electron="${tmpdir}/electron39/electron"
"\${electron}" "\$@"
EOF
  chmod +x "${tmpdir}/codex-desktop"

  config_file="${tmpdir}/electron-config"
  printf '%s\n' "${tmpdir}/manual/electron" >"${config_file}"

  run_wrapper_with_electron_config "${tmpdir}" "${config_file}"

  expected="${tmpdir}/manual/electron"
  actual="$(cat "${tmpdir}/invoked-electron")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "expected configured electron ${expected}, got ${actual}"
}

test_resolves_upstream_launcher_appdir_codex_electron() {
  local tmpdir
  local expected
  local actual
  local upstream_appdir

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  setup_app "${tmpdir}"
  upstream_appdir="${tmpdir}/upstream-app"
  install -dm755 "${upstream_appdir}"
  make_fake_electron "${tmpdir}/electron41/electron"
  make_fake_electron "${tmpdir}/electron42/electron"
  ln -s "${tmpdir}/electron41/electron" "${tmpdir}/app/codex"
  ln -s "${tmpdir}/electron42/electron" "${upstream_appdir}/codex"

  cat >"${tmpdir}/codex-desktop" <<EOF
#!/usr/bin/env bash
appdir="${upstream_appdir}"
electron="\${appdir}/codex"
"\${electron}" "\$@"
EOF
  chmod +x "${tmpdir}/codex-desktop"

  run_wrapper "${tmpdir}"

  expected="${upstream_appdir}/codex"
  actual="$(cat "${tmpdir}/invoked-electron")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "expected upstream launcher appdir electron ${expected}, got ${actual}"
}

test_prefers_upstream_launcher_electron_over_appdir_codex
test_explicit_electron_env_wins
test_electron_config_file_wins_over_upstream_launcher
test_resolves_upstream_launcher_appdir_codex_electron
printf 'ok - wrapper electron selection\n'
