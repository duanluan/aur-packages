# agents-anywhere

`agents-anywhere` builds the desktop workbench of
[Agents Anywhere](https://github.com/anywhere-labs/Agents-Anywhere) from
source for Arch Linux on x86_64 and aarch64.

Agents Anywhere is an open-source cross-device AI agent workbench: run and
control coding agents (Claude Code, Codex, OpenCode and others via ACP) on
your devices from one desktop app, phone, or browser.

The upstream project publishes only macOS and Windows installers — the
official download page has no Linux section — although its electron-builder
configuration carries a Linux target. This package builds the
`desktop-workbench` workspace from the tagged source on your machine with
yarn 4 + electron-builder, bundling the official uv and
python-build-standalone runtimes for the build host architecture the same
way upstream bundles them for macOS and Windows.

## Install

```bash
paru -S agents-anywhere
```

or

```bash
yay -S agents-anywhere
```

The build downloads several hundred MB (node modules, the Electron runtime,
uv, python-build-standalone) on first run.

## Usage

Launch `agents-anywhere` from a terminal or "Agents Anywhere" from the
application menu.

## Notes

- No `-bin` suffix: this is a source build. Upstream does not publish a
  lockfile, so dependency resolution floats within semver ranges at build
  time — rebuild if an upstream dependency breaks the build.
- The upstream repository carries no LICENSE file at the time of packaging;
  `license` stays `NOASSERTION` until upstream adds one.
- The bundled uv/python runtimes live under `/opt/agents-anywhere/resources/`
  and are managed by the app itself, mirroring the official macOS/Windows
  layout.
- Network access is required at build time (npm registry, GitHub releases
  for Electron/uv/python). Set `ELECTRON_MIRROR`, `PYTHON_BUNDLE_MIRROR` or
  run behind a proxy if direct GitHub access is unavailable.
- Desktop-Next (`desktop-next` workspace) is the experimental successor and
  is intentionally not packaged.
