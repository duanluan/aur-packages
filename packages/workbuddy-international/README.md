# workbuddy-international

`workbuddy-international` builds an unofficial Linux port of the
[WorkBuddy AI international edition](https://www.workbuddy.ai) for Arch
Linux on x86_64 and aarch64.

Tencent publishes macOS and Windows clients for the international line only —
there is no official Linux build. This package converts the official macOS
build into a working Linux Electron app on your own machine at build time; no
proprietary content is redistributed by the package itself.

Not affiliated with, endorsed by, or supported by Tencent. WorkBuddy /
WorkBuddy AI / CodeBuddy are Tencent products. See
[DISCLAIMER](DISCLAIMER).

## How it works

The international and domestic (workbuddy.cn) clients share one codebase;
the edition is selected by a baked-in `cli/product.json`. The macOS build
contains the full cross-platform core and only needs its platform binaries
swapped:

1. Download the official darwin-x64 / darwin-arm64 archive (URL and version
   from the official update feed
   `https://www.workbuddy.ai/v2/update?platform=workbuddy-darwin-x64`).
2. Swap the bundled macOS Electron runtime for the same-version Linux
   runtime from the official Electron releases.
3. Rebuild native Node modules for Linux/Electron (`better-sqlite3`,
   `node-pty`) and install Linux platform packages
   (`@lydell/node-pty-linux-{x64,arm64}`, `@vscode/ripgrep`).
4. Apply anchor-tolerant runtime patches so the main window opens and the
   tray menu is populated.

The conversion toolchain (`install.sh`, `lib-*`) is vendored from the
MIT-licensed community project
[workbuddy-linux](https://github.com/JipZeonGit/workbuddy-linux)
(see `LICENSE.port-tool`).

## Install

```bash
paru -S workbuddy-international
```

or

```bash
yay -S workbuddy-international
```

Replacing the old `workbuddy-international-bin` package: this package
`provides`/`conflicts` it, so installing this one replaces the old one in a
single transaction. The command name (`workbuddy-international`), desktop
entry and data directories are unchanged.

## Usage

Launch `workbuddy-international` from a terminal, or "WorkBuddy AI
(International)" from the application menu. Sign in with the international
account (Google / GitHub OAuth on workbuddy.ai — separate from the domestic
workbuddy.cn account system).

## Notes

- No auto-update on Linux: upstream publishes no international Linux feed,
  and the in-app updater no-ops by design. Upgrade by rebuilding this
  package (the auto-update tooling in this repository repins versions).
- Session runtimes (node 22 / python 3.13) are taken from the official
  domestic-edition Linux deb at build time: the international darwin build
  bundles macOS/Windows runtimes only, while the Linux app expects
  `resources/runtime/{node,python}`. Without them the session daemon
  crash-loops and the app warns about a "critical component". The runtime
  version is pinned independently in the PKGBUILD (`_cn_pkgver`).
- The port also patches the storage bootstrap: `electron.workbuddyStorage`
  is an API of Tencent's customized Electron; on the vanilla Electron
  runtime used here it is absent and gets a no-op shim, so local at-rest
  encryption runs in its degraded policy without the startup warning.
- Tencent Docs deep collaboration is degraded (the native docs engine ships
  macOS-only binaries; basic document read/write via cloud API still works).
- arm64 builds from the darwin-arm64 archive and the arm64 domestic deb;
  the port patches are arch-aware. arm64 is untested locally (built and
  verified on x86_64).
- Do NOT report port-specific issues to Tencent support.
