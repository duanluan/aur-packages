# minimax-code

`minimax-code` packages the [MiniMax Code](https://agent.minimax.cn/) terminal
coding agent (`mcode` CLI) for Arch Linux.

Upstream publishes the CLI as the npm package `@minimax-ai/code`; there is no
standalone Linux binary. The package installs the npm tree under
`/opt/minimax-code` and builds the `better-sqlite3` native binding against the
distribution Node.js headers, so no npm global install is needed.

## Install

With `paru`:

```bash
paru -S minimax-code
```

With `yay`:

```bash
yay -S minimax-code
```

Manual install from this repository:

```bash
cd packages/minimax-code
makepkg -si
```

## Usage

```bash
mcode
```

Run `mcode --help` for the full command list. `mcode-tools` provides the
auxiliary tooling launcher.

## Notes

- `/usr/bin/mcode` always runs `/usr/bin/node`. The native binding is compiled
  against that Node's ABI, so running the CLI with another Node version may fail
  to load it.
- The package keeps only the current architecture's prebuilt packages for
  ripgrep, clipboard, `@ubjs/node`, and `@trycua/cua-driver`, and drops the
  embedded computer-use components that only ship for macOS and Windows.
- `update.sh` follows the npm `latest` tag and the `better-sqlite3` pin in the
  upstream `optionalDependencies`.
- The desktop MiniMax Code application (the 3.x downloads on the website) is a
  separate product and is not part of this package.
