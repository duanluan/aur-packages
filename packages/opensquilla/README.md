# opensquilla

`opensquilla` repackages the official macOS OpenSquilla desktop release for
Arch Linux.

## Install

With `paru`:

```bash
paru -S opensquilla
```

With `yay`:

```bash
yay -S opensquilla
```

Manual install from this repository:

```bash
cd packages/opensquilla
makepkg -si
```

## Notes

- The package installs the `opensquilla` launcher.
- The package reuses the official macOS DMG as the resource source and runs it
  with Arch Linux's `electron42`.
- The launcher reads optional user flags from `~/.config/opensquilla-flags.conf`.
- Upstream ships the desktop shell as an Electron 42.4.0 build with packaged
  `app.asar`, `boot.html`, and `runtime/` resources.
