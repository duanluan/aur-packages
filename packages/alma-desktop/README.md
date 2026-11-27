# alma-desktop

`alma-desktop` repackages the official Alma Linux release (`.deb`) for Arch
Linux. Alma is a desktop AI agent harness that also works as a GUI client
for herdr; it is proprietary freeware with no published source code.

## Install

With `paru`:

```bash
paru -S alma-desktop
```

With `yay`:

```bash
yay -S alma-desktop
```

Manual install from this repository:

```bash
cd packages/alma-desktop
makepkg -si
```

## Notes

- Source is the versioned official deb:
  `https://github.com/yetone/alma-releases/releases/download/v<version>/alma-<version>-linux-amd64.deb`
- The app is installed to `/opt/alma` together with a `/usr/bin/alma-desktop`
  launcher; the desktop entry, hicolor icons and third-party notices come
  straight from the deb.
- Upstream ships x86_64 and aarch64 Linux builds; both are packaged.
- `webkit2gtk-4.1`, `libayatana-appindicator`, `libsecret` and `alsa-lib` are
  loaded at runtime and are hard dependencies. `libsecret` missing degrades
  silently to storing credentials unencrypted, which is why it is required
  rather than optional.
- `ffmpeg` (H.264 encoder for remote access), `gtk-layer-shell` (Wayland layer
  shell windows) and `libpulse` (PulseAudio output) are loaded if present; the
  app runs without them.
- Upstream rebuilds the same version several times a day. The packaged
  `pkgver` follows the version field and `pkgrel` is bumped when the debs
  change without a version change.
- The AUR package `alma-desktop-bin` (maintained separately) packages the same
  closed-source build; this package conflicts with it. `alma-appimage` is the
  outdated AppImage package for the same app and is also declared as a
  conflict.
- The package name carries no `-bin` suffix because the software is closed
  source and has no buildable source package, following
  [the repository packaging rules](../../docs/aur-packaging-rules.md).
- The command line launcher is `/usr/bin/alma-desktop`, not `/usr/bin/alma`:
  the unrelated AUR package `alma` (a live USB writer) already owns
  `/usr/bin/alma`. The app keeps installing its own CLI to `~/.local/bin/alma`
  on first launch.
