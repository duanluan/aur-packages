# doubao-cli

`doubao-cli` packages the official Linux x64 release of the
[Doubao CLI](https://www.doubao.com/work/docs/zh-cn/doubao-cli) for Arch Linux.

Doubao CLI is ByteDance's terminal client for Doubao. It runs as an interactive
session, as single-shot prompts (`doubao -p`), and it can be called from scripts
and other agents. It works on local files and commands inside a chosen
directory, and it can take on tasks dispatched from the phone or desktop app.

## Install

With `paru`:

```bash
paru -S doubao-cli
```

With `yay`:

```bash
yay -S doubao-cli
```

Manual install from this repository:

```bash
cd packages/doubao-cli
makepkg -si
```

## Usage

```bash
doubao login                        # scan the QR code shown in the terminal
doubao auth status --verify         # confirm the saved session works
cd your-project && doubao           # start the interactive session
doubao -p "说明当前目录的项目结构"    # single-shot prompt
```

Run `doubao --help` for the full command list.

## Notes

- The package installs the official archive under `/opt/doubao-cli` and links
  `/usr/bin/doubao` to it. Keep the whole directory: the binary loads
  `resources/js_app` and the bundled `.so` files relative to its real path.
- Node.js is not needed. Upstream ships the CLI through npm, but the npm package
  only contains launcher scripts and the download manifest; this package packs
  the Linux archive listed in that manifest directly.
- Upstream publishes Linux x64 only, so the package is `x86_64`.
- `browser-use` (the optional browser automation runtime) is not bundled. It
  downloads a Chromium build and creates a Python virtual environment on first
  use, and needs `curl`, `dpkg` and `python` for that.
- Login data and chat history live in `~/.local/share/doubao_cli` and
  `~/.doubao-cli`, outside the package.
- Do not run `doubao update`. Upstream's updater installs into
  `~/.local/share/doubao_cli/app`, which is not managed by pacman; update with
  `pacman -Syu` instead.
- The binary is proprietary freeware; the package ships it unmodified.
