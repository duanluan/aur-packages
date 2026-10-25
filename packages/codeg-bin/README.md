# codeg-bin

`codeg-bin` repackages the official Linux `.deb` releases of
[Codeg](https://github.com/xintaofei/codeg) for Arch Linux on x86_64 and
aarch64.

Codeg is a collaborative multi-agent AI coding workspace that aggregates
sessions from Claude Code, Codex, OpenCode, Pi, Grok, and other coding agents.

## Install

With `paru`:

```bash
paru -S codeg-bin
```

With `yay`:

```bash
yay -S codeg-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/codeg-bin.git
cd codeg-bin
makepkg -si
```

## Usage

Start the desktop app from the application menu, or run:

```bash
codeg
```

The upstream package also provides:

```bash
codeg-cli --help
codeg-mcp --help
codeg-computer-helper --help
```

## Notes

- The package preserves the upstream Tauri desktop application, CLI, MCP
  sidecar, and bundled Web assets.
- Since upstream 0.33.0, `codeg-server` is no longer bundled with the desktop
  package; it ships as separate `codeg-server-linux-*.tar.gz` release assets
  and is not part of `codeg-bin`.
- The desktop launcher disables WebKit's DMABUF renderer by default to avoid a
  blank window on affected Linux graphics stacks. Set
  `WEBKIT_DISABLE_DMABUF_RENDERER=0` to override it.
- Application state and configuration are stored in the current user's home
  directory.
