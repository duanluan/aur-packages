# minimax-hub-bin

`minimax-hub-bin` packages the official MiniMax Hub macOS desktop release for
Arch Linux by reusing the Electron application resources with the system
Electron runtime.

The package supports `x86_64` and `aarch64`. It downloads the matching official
macOS DMG, installs the app resources under `/usr/lib/minimax-hub-bin`, and
uses native Arch packages for Electron and FFmpeg. OpenCode is discovered from
`/usr/bin/opencode` or common npm global install locations.

## Install

With `paru`:

```bash
paru -S minimax-hub-bin
```

With `yay`:

```bash
yay -S minimax-hub-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/minimax-hub-bin.git
cd minimax-hub-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
minimax-hub
```

## Notes

- The upstream project does not currently publish an official Linux build.
- The built-in desktop updater is disabled; update through AUR instead.
- Install `opencode` from the Arch repositories, or run
  `npm i -g opencode-ai` before opening a workspace.
- Optional Electron flags can be placed in `~/.config/minimax-hub-flags.conf`.
