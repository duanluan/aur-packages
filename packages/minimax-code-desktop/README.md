# minimax-code-desktop

`minimax-code-desktop` packages the official MiniMax Code macOS desktop app
for Arch Linux by running its Electron resources on the distribution Electron
runtime.

Upstream only publishes Windows and macOS installers; there is no Linux build.
The package extracts `app.asar` and `app.asar.unpacked` from the official
`MiniMax Code-<version>.dmg`, replaces the macOS native modules with Linux
builds of the same versions, and runs everything on Electron 42.

On `x86_64` the distribution `electron42` package is used. Arch Linux ARM has
no `electron42`, so the `aarch64` build ships the official Electron 42.11.10
runtime under `/usr/lib/electron42` and depends on its shared libraries
directly.

## Install

With `paru`:

```bash
paru -S minimax-code-desktop
```

With `yay`:

```bash
yay -S minimax-code-desktop
```

Manual install from this repository:

```bash
cd packages/minimax-code-desktop
makepkg -si
```

## How it works

- `patch-asar.js` rewrites the packed main-process files in `app.asar`:
  - `process.resourcesPath` becomes overridable with
    `MINIMAX_CODE_RESOURCES_PATH`, because the system Electron resolves it to
    its own resources directory;
  - `app.isPackaged` is forced to `true`, so the app reads `.env.local` from the
    asar and uses the production resource paths;
  - the built-in updater is disabled with `MINIMAX_CODE_DISABLE_UPDATER=1`;
  - the deep-link registration no longer takes the development branch on Linux.
- `sync-unpacked.js` rewrites the asar header so the replaced Linux native
  modules are registered as unpacked entries.
- Native modules are swapped for the same versions the upstream macOS build
  bundles: ripgrep 1.18.0, clipboard 0.3.9, `@trycua/cua-driver` 0.34.1,
  `@ubjs/node` 0.31.0-3, `node-screenshots` 0.2.8, `@napi-rs/keyring` 2.1.1,
  `better-sqlite3` 12.11.1 (Electron ABI 146 prebuilt), and `node-pty` 1.1.0
  compiled from source against the Electron headers.
- `resources/computer-use` (macOS-only) and the Windows NSIS installer files
  are dropped.

## Notes

- `aarch64` is packaged from the arm64 dmg with arm64 native modules. The
  asar patching and module replacement were verified on the arm64 payload, but
  the package was not built or started on real ARM hardware. `node-pty` is
  compiled on the target machine, so a native ARM build environment is
  required (no cross-compilation is set up).
- The built-in updater is disabled. Updates arrive through AUR.
- This is an unofficial Linux port. Upstream does not support Linux; features
  that depend on macOS frameworks (for example Computer Use) will not work.
- The app is closed source. The package ships the upstream resources
  unmodified apart from the patches listed above.
- Only the login window was smoke-tested. Behaviour after signing in was not
  verified.
- `update.sh` follows the cn download page (`code.minimax.cn`) and rewrites the
  dmg urls and checksums in the PKGBUILD for both architectures. When upstream
  moves to a different Electron major, `_electron` and the better-sqlite3 ABI
  in the PKGBUILD must be updated by hand.
