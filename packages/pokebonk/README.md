# pokebonk

`pokebonk` packages the official Linux x86_64 AppImage release of the [PokéBonk](https://pokebonk.com) desktop app for Arch Linux.

PokéBonk is a free, unofficial 3D Pokémon-style survival fan-game. This desktop client is built and released by the game's author at [CharcherGit/pokebonk-app](https://github.com/CharcherGit/pokebonk-app).

## Install

With `paru`:

```bash
paru -S pokebonk
```

With `yay`:

```bash
yay -S pokebonk
```

Manual install from this repository:

```bash
cd packages/pokebonk
makepkg -si
```

## Usage

Start the game:

```bash
pokebonk
```

Or launch it from the desktop entry (Game category).

## Notes

- The package installs the extracted AppImage under `/opt/pokebonk`; the `pokebonk` command runs its `AppRun`.
- The upstream AppImage ships with `--no-sandbox` in its desktop entry, which the package keeps.
- The game is a non-commercial fan project; game assets remain the property of their original copyright holders. Electron/Chromium third-party licenses are installed under `/usr/share/licenses/pokebonk/`.
