# mirasim

`mirasim` repackages the official Mirasim Linux `.deb` for Arch Linux.
Mirasim is a proprietary desktop app that runs several agent CLIs on the
user's own subscriptions and puts them in shared team spaces; no source
code is published.

## Install

With `paru`:

```bash
paru -S mirasim
```

With `yay`:

```bash
yay -S mirasim
```

Manual install from this repository:

```bash
cd packages/mirasim
makepkg -si
```

## Notes

- Source is the versioned official deb:
  `https://cdn-assets.mirasim.ai/mirasim/releases/v<version>/Mirasim-<version>-linux-amd64.deb`
  (the download page lists the current version; the CDN has no `latest`
  pointer).
- The app is installed to `/opt/Mirasim` with a `/usr/bin/mirasim-desktop`
  launcher; the desktop entry, hicolor icons and changelog come straight
  from the deb.
- `chrome-sandbox` keeps the setuid bit, and the launcher falls back to
  `--no-sandbox` only when neither sandbox mechanism is usable.
- Upstream ships x86_64 and aarch64 Linux builds; both are packaged.
- The package is named without `-bin` because the software is closed
  source and has no buildable sources, per the AUR non-free guidelines.
- The orphaned AUR package `mirasim-bin` packages the same app; this
  package conflicts with it.
- The standalone `mirasim` server CLI installed by `install.sh` is a
  different artifact and is not covered by this package.
