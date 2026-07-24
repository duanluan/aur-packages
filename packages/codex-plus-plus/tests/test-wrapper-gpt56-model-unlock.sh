#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
WRAPPER="${PACKAGE_DIR}/codex-desktop-app-wrapper.sh"
MODEL_FILTER_JS='function filter({useHiddenModels:o,supportedReasoningEfforts:r}){let l=o,t=new Set;return models.filter(n=>{if(l?t.has(n.model):!n.hidden){return n.supportedReasoningEfforts}})}'
PATCHED_FILTER_JS='if(n.model===`gpt-5.6-sol`||(l?t.has(n.model):!n.hidden)){'

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

setup_fixture() {
  local tmpdir="$1"
  local model_asset_content="$2"

  install -dm755 \
    "${tmpdir}/app/resources" \
    "${tmpdir}/app/content/webview/assets" \
    "${tmpdir}/runtime"
  touch "${tmpdir}/app/resources/app.asar"
  printf 'console.log("plugin auth unlocked");\n' >"${tmpdir}/plugin-auth-unlocked.js"
  printf 'console.log("original plugin auth");\n' \
    >"${tmpdir}/app/content/webview/assets/plugin-auth-test.js"
  printf '%s\n' "${model_asset_content}" \
    >"${tmpdir}/app/content/webview/assets/model-list.js"

  cat >"${tmpdir}/electron" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${ELECTRON_RENDERER_URL}" >"${CODEXPP_TEST_RENDERER_URL}"
model_asset="$(find -L "${TMPDIR}" -path '*/assets/model-list.js' -type f -print -quit)"
[[ -n "${model_asset}" ]]
cp "${model_asset}" "${CODEXPP_TEST_MODEL_ASSET}"
EOF
  chmod +x "${tmpdir}/electron"
}

run_wrapper() {
  local tmpdir="$1"
  local stderr_file="$2"
  local port

  port="$(free_port)"
  env \
    TMPDIR="${tmpdir}/runtime" \
    CODEXPP_OPENAI_CODEX_APP_DIR="${tmpdir}/app" \
    CODEXPP_OPENAI_CODEX_ELECTRON="${tmpdir}/electron" \
    CODEXPP_PLUGIN_AUTH_UNLOCK_FILE="${tmpdir}/plugin-auth-unlocked.js" \
    CODEXPP_RENDERER_PORT="${port}" \
    CODEXPP_TEST_MODEL_ASSET="${tmpdir}/captured-model-list.js" \
    CODEXPP_TEST_RENDERER_URL="${tmpdir}/renderer-url" \
    "${@:3}" \
    "${WRAPPER}" >/dev/null 2>"${stderr_file}"

  printf 'http://127.0.0.1:%s/\n' "${port}" >"${tmpdir}/expected-renderer-url"
}

assert_renderer_url() {
  local tmpdir="$1"
  local actual_renderer_url
  local expected_renderer_url

  actual_renderer_url="$(cat "${tmpdir}/renderer-url")"
  expected_renderer_url="$(cat "${tmpdir}/expected-renderer-url")"
  [[ "${actual_renderer_url}" == "${expected_renderer_url}" ]] ||
    fail "expected renderer URL ${expected_renderer_url}, got ${actual_renderer_url}"
}

assert_default_patch() {
  local tmpdir

  tmpdir="$(mktemp -d)"
  setup_fixture "${tmpdir}" "${MODEL_FILTER_JS}"
  run_wrapper "${tmpdir}" "${tmpdir}/stderr" \
    ELECTRON_RENDERER_URL="http://stale.invalid/"

  grep -Fq "${PATCHED_FILTER_JS}" "${tmpdir}/captured-model-list.js" ||
    fail "GPT-5.6 Sol was not added to the model filter"

  grep -Fq 'if(l?t.has(n.model):!n.hidden){' \
    "${tmpdir}/app/content/webview/assets/model-list.js" ||
    fail "the installed webview asset was modified"

  assert_renderer_url "${tmpdir}"
  rm -rf "${tmpdir}"
}

assert_disabled_patch() {
  local tmpdir

  tmpdir="$(mktemp -d)"
  setup_fixture "${tmpdir}" "${MODEL_FILTER_JS}"
  run_wrapper "${tmpdir}" "${tmpdir}/stderr" CODEXPP_UNLOCK_GPT56=0

  ! grep -Fq 'gpt-5.6-sol' "${tmpdir}/captured-model-list.js" ||
    fail "GPT-5.6 Sol was added while CODEXPP_UNLOCK_GPT56=0"

  assert_renderer_url "${tmpdir}"
  rm -rf "${tmpdir}"
}

assert_ambiguous_patch_is_nonfatal() {
  local ambiguous_asset
  local tmpdir

  tmpdir="$(mktemp -d)"
  ambiguous_asset="${MODEL_FILTER_JS} ${MODEL_FILTER_JS}"
  setup_fixture "${tmpdir}" "${ambiguous_asset}"
  run_wrapper "${tmpdir}" "${tmpdir}/stderr"

  ! grep -Fq 'gpt-5.6-sol' "${tmpdir}/captured-model-list.js" ||
    fail "ambiguous model filter was patched"

  grep -Fq 'matched multiple times' "${tmpdir}/stderr" ||
    fail "ambiguous model filter warning was not printed"

  assert_renderer_url "${tmpdir}"
  rm -rf "${tmpdir}"
}

assert_default_patch
assert_disabled_patch
assert_ambiguous_patch_is_nonfatal

printf 'ok - wrapper GPT-5.6 model unlock\n'
