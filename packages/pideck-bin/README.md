# pideck-bin

`pideck-bin` repackages the official Linux `.deb` release of
[PiDeck](https://github.com/ayuayue/PiDeck) for Arch Linux on x86_64.

PiDeck is an open-source desktop workbench for managing pi Agent sessions in
local project directories. It also imports Codex and Claude local sessions and
includes multi-project workspaces, session history, Git integration, a built-in
terminal, model configuration, and plugin management.

## Install

With `paru`:

```bash
paru -S pideck-bin
```

With `yay`:

```bash
yay -S pideck-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/pideck-bin.git
cd pideck-bin
makepkg -si
```

## Usage

Start PiDeck from the application menu, or run either command:

```bash
pideck
pi-desktop
```

## Notes

- This package uses the upstream `.deb` release and does not require FUSE.
- The upstream release currently supports x86_64 Linux only.
- `git` is optional at the package level but required for PiDeck's Git
  integration features.
- Application state and configuration are stored in the current user's home
  directory.
