# minimax-design

`minimax-design` packages the official MiniMax Design macOS desktop release for
Arch Linux by reusing the Electron application resources with the system
Electron runtime.

MiniMax Design was formerly known as MiniMax Hub. The package was renamed from
`minimax-hub`, which remains available as a transitional package.

The package supports `x86_64` and `aarch64`. It downloads the matching official
macOS zip, installs the app resources under `/usr/lib/minimax-design`, and uses
native Arch packages for Electron and FFmpeg. OpenCode is discovered from
`/usr/bin/opencode` or common npm global install locations.

## Install

With `paru`:

```bash
paru -S minimax-design
```

With `yay`:

```bash
yay -S minimax-design
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/minimax-design.git
cd minimax-design
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
minimax-design
```

## Notes

- The upstream project does not currently publish an official Linux build.
- The built-in desktop updater is disabled; update through AUR instead.
- Install `opencode` from the Arch repositories, or run
  `npm i -g opencode-ai` before opening a workspace.
- Optional Electron flags can be placed in `~/.config/minimax-design-flags.conf`
  (the former `~/.config/minimax-hub-flags.conf` is still honored).
