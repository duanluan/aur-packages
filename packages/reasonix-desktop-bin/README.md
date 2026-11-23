# reasonix-desktop-bin

`reasonix-desktop-bin` repackages the prebuilt Linux `.deb` release of
[Reasonix Studio](https://github.com/esengine/DeepSeek-Reasonix) for Arch Linux.

Reasonix Studio is the Electron desktop GUI for Reasonix, a terminal-native AI
coding agent working against the DeepSeek API.

## Notes

- Upstream used to publish the desktop app as "Reasonix Desktop" on the
  `desktop-v*` tag line. That line ended at 1.39.11; the app was renamed to
  Reasonix Studio and continues on `studio-v*` with 2.x version numbers. This
  package follows the Studio line while keeping its original AUR name so
  existing installations upgrade in place.
- The bundle ships its own pinned Electron runtime together with its helper
  binaries (`reasonix-studio-host`, `cua-driver`), so the package only depends
  on the shared libraries and desktop integration those binaries load.
- `bubblewrap` is an optional dependency: the agent host uses it to sandbox
  shell commands.
- The in-app self-update helper and its polkit policy are deliberately not
  installed — pacman owns upgrades, and self-updating would overwrite
  package-tracked files.

## Install

With `paru`:

```bash
paru -S reasonix-desktop-bin
```

With `yay`:

```bash
yay -S reasonix-desktop-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/reasonix-desktop-bin.git
cd reasonix-desktop-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
reasonix-studio
```

## Conflicts

This package conflicts with `reasonix-desktop`, `reasonix-studio`,
`deepseek-reasonix-desktop`, and `deepseek-reasonix-desktop-bin` — only one
Reasonix desktop package should be installed at a time.
