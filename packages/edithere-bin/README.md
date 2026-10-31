# edithere-bin

`edithere-bin` packages the official Linux x86_64 AppImage release of [EditHere](https://github.com/Inginnng/EditHere) for Arch Linux.

EditHere (改这里) is a screenshot annotation and visual feedback tool: take a screenshot, write comments, adjust the layout directly, and hand the edit intent to AI in one step.

## Install

With `paru`:

```bash
paru -S edithere-bin
```

With `yay`:

```bash
yay -S edithere-bin
```

Manual install from this repository:

```bash
cd packages/edithere-bin
makepkg -si
```

## Usage

Start the desktop app:

```bash
edithere
```

Capture a screen region directly (also available as a desktop action):

```bash
edithere --capture
```

Run the CLI:

```bash
edithere --cli --help
```

## Notes

- The package installs the extracted AppImage under `/opt/edithere-bin`; the `edithere` command runs its bundled `AppRun`, which sets up the bundled Qt and PipeWire runtime.
- EditHere is licensed under the PolyForm Noncommercial License 1.0.0: free for noncommercial use only, commercial use requires a separate license from the author. The license text and required notice are installed under `/usr/share/licenses/edithere-bin/`.
