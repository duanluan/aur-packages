# apifox

`apifox` packages the official x86_64 Linux manual bundle of
[Apifox](https://apifox.com/), an API documentation, debugging, mocking, and
automated testing tool.

## Install

With `paru`:

```bash
paru -S apifox
```

With `yay`:

```bash
yay -S apifox
```

Manual install from this repository:

```bash
cd packages/apifox
makepkg -si
```

## Launch

Start Apifox from your application menu, or run:

```bash
apifox
```

## Download source and captcha note

The official download gateway at `file-assets.apifox.com` may redirect some
requests to Apifox's anti-abuse captcha page. This package does not implement
captcha solving, OCR, browser automation, or any blacklist bypass.

Instead, it downloads the same official manual Linux archive from Apifox's
public Aliyun OSS CDN object:

```text
https://file-assets-cdn.oss-cn-hangzhou.aliyuncs.com/download/Apifox-linux-manual-latest.tar.gz
```

The archive is verified with a SHA-256 checksum in `PKGBUILD`. When Apifox
changes the archive, run `./update.sh` to refresh the version and checksum.

## Package layout

- The upstream self-contained Electron bundle is installed under
  `/opt/Apifox`.
- `/usr/bin/apifox` points to the upstream launcher.
- The package installs a desktop entry and the upstream Apifox logo.
- Apifox's Electron and Chromium license files are installed under
  `/usr/share/licenses/apifox`.

The package conflicts with the older `api-fox-bin` package because both install
the `apifox` command and desktop application.
