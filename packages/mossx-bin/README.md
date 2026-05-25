# mossx-bin

`mossx-bin` packages the official x86_64 AppImage release of
[MossX](https://www.mossx.ai/download) for Arch Linux.

MossX is a desktop client for Claude Code, Codex, Gemini, and Opencode.

## Install

With `paru`:

```bash
paru -S mossx-bin
```

With `yay`:

```bash
yay -S mossx-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/mossx-bin.git
cd mossx-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
mossx
```

## Notes

- The package installs the upstream AppImage under `/opt/mossx`.
- The `ccgui` and `cc-gui` commands are provided as compatibility aliases.
- The download page links to the upstream `desktop-cc-gui` release assets.
