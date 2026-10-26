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
- Dependency install scripts are disabled (`YARN_ENABLE_SCRIPTS=false`):
  the electron/sharp postinstalls only serve local development and would
  download from GitHub on every build; the build itself never needs them.
- All GitHub build-time downloads (uv bundle, python-build-standalone, the
  Electron zip) try the official URL first and fall back to a public proxy,
  resuming partial transfers and verifying everything against the official
  checksum files. Downloads are cached under `~/.cache/electron/` and
  `~/.cache/agents-anywhere-build/`, so rebuilds reuse them.
- If direct GitHub is unreachable and you prefer a proxy, build with your
  proxy exported (`http_proxy=… https_proxy=… makepkg -si` or
  `proxychains makepkg -si`); every download in the PKGBUILD honors the
  standard proxy variables.
- The bundled uv/python runtimes live under `/opt/agents-anywhere/resources/`
  and are managed by the app itself, mirroring the official macOS/Windows
  layout.
- The font patch switches Geist/Instrument Serif to system font stacks
  because next/font/google requires Google Fonts access at build time.
- Desktop-Next (`desktop-next` workspace) is the experimental successor and
  is intentionally not packaged.
