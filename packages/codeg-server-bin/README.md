# codeg-server-bin

`codeg-server-bin` repackages the official `codeg-server-linux-*.tar.gz`
release assets of [Codeg](https://github.com/xintaofei/codeg) for Arch Linux
on x86_64 and aarch64.

Codeg is a collaborative multi-agent AI coding workspace that aggregates
sessions from Claude Code, Codex, OpenCode, Pi, Grok, and other coding agents.
This package ships only the standalone server for headless or remote setups;
the desktop application is packaged separately as `codeg-bin`.

## Install

With `paru`:

```bash
paru -S codeg-server-bin
```

With `yay`:

```bash
yay -S codeg-server-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/codeg-server-bin.git
cd codeg-server-bin
makepkg -si
```

## Usage

```bash
codeg-server
```

The server accepts no `--help` flag and starts directly; logs are written to
`~/.local/share/codeg/logs/` and the data directory defaults to
`~/.local/share/codeg` (override with `CODEG_DATA_DIR`).

The package keeps the upstream tarball layout (the `codeg-server` binary,
`codeg-cli`, `codeg-mcp`, `codeg-computer-helper`, and the `web` assets) under
`/usr/lib/codeg-server/`, and exposes `/usr/bin/codeg-server` as a launcher.

## Notes

- Since upstream 0.33.0 the server is no longer bundled with the desktop
  package, which is why it is packaged separately from `codeg-bin`.
- The server resolves its static Web directory relative to its working
  directory (it looks for `./web` and falls back to `./out`), so the launcher
  starts it inside `/usr/lib/codeg-server/` where the bundled assets live.
- The package can be installed alongside `codeg-bin`; the bundled copies of
  `codeg-cli`, `codeg-mcp`, and `codeg-computer-helper` live inside
  `/usr/lib/codeg-server/` and do not conflict with the `codeg-bin` commands
  in `/usr/bin`.
- Server data and configuration are stored in the current user's home
  directory.
