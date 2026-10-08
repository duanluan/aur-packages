# ldtk-git

`ldtk-git` builds [LDtk](https://github.com/deepnight/ldtk) from the git
`master` branch for Arch Linux.

LDtk is a modern and efficient 2D level editor with a strong focus on
user-friendliness, by Sébastien Bénard (deepnight). This package tracks
upstream master instead of the latest release tag (`ldtk` in AUR).

## Differences from AUR `ldtk`

- Source is the git `master` branch instead of a release tarball.
- haxelib dependencies are installed via upstream `setup.hxml`, following
  each library's default branch instead of pinned commits.
- Command name stays `ldtk`; the package `conflicts=('ldtk')` so both
  cannot be installed at the same time.

## Install

With `paru`:

```bash
paru -S ldtk-git
```

With `yay`:

```bash
yay -S ldtk-git
```

Manual build from this repository:

```bash
cd packages/ldtk-git
makepkg -si
```

## Build notes

- Build requires `haxe`, `nodejs` and `npm`; haxelib dependencies are
  installed into a per-build local repo under `$srcdir`, not the global
  one.
- The Haxe sources compile to `app/assets/main.js` and
  `app/assets/js/renderer.js`, then `electron-builder` packages an
  Electron app into `app/redist/linux-unpacked`.
- The unpacked tree is installed to `/usr/share/ldtk-git`, with
  `/usr/bin/ldtk` symlinked to the bundled Electron binary.

## Launch

From the application menu ("LDtk") or run `ldtk` in a terminal.
