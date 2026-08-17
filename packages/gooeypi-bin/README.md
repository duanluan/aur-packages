# gooeypi-bin

`gooeypi-bin` repackages the official Arch Linux `.pacman` releases of
[GooeyPi](https://github.com/am-will/gooey-pi).

GooeyPi is a desktop workspace for Pi, OMP, and Prime Agent. It provides a
shared interface for projects, agent sessions, terminals, Git changes,
schedules, capabilities, and browser automation.

## Install

With `paru`:

```bash
paru -S gooeypi-bin
```

With `yay`:

```bash
yay -S gooeypi-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/gooeypi-bin.git
cd gooeypi-bin
makepkg -si
```

## Launch

Start GooeyPi from the application menu, or run:

```bash
gooeypi
```

## Notes

- The package supports `x86_64` and `aarch64` using the matching official
  prebuilt Arch release.
- The upstream `/opt/GooeyPi` layout is preserved, including its bundled
  Electron runtime and native `node-pty` and ZeroMQ modules.
- Pi, OMP, and Prime Agent are separate harnesses. Install and configure at
  least one of them before starting an agent session in GooeyPi.
- Optional voice credentials use the desktop secret storage backend when one
  is available.
- Application data and harness credentials remain in the current user's home
  directory.
