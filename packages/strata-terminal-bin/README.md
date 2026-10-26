# strata-terminal-bin

`strata-terminal-bin` packages the prebuilt **Strata Terminal** (the `strata`
CLI) of [Strata](https://github.com/Niko1221/Strata) for Arch Linux x86_64.

Strata runs frontier open models — Qwen3.8-Flash-Next (125B MoE) and
DeepSeek V4.1-Flash — on a consumer gaming PC with an NVIDIA or AMD GPU,
exposing a local OpenAI- and Anthropic-compatible API that Claude Code,
Codex CLI, OpenCode and other agents can connect to. Chats and files stay
on your machine. MIT licensed.

## What is packaged

The Terminal distribution is self-contained: it bundles its own Python 3.12
runtime, tokenizer vocabularies, expert profiles and tooling under
`/opt/strata-terminal`, and installs `/usr/bin/strata`.

The **GPU-specific inference engine and the model weights are not part of
this package** — by design. On first use `strata launch` detects your
graphics card, tells you the download size, and fetches the matching signed
engine build from the official Strata releases into
`~/.local/share/strata/`. This mirrors exactly what the official one-line
installer does. `strata serve`, `strata runtime` and `strata monitor` never
download anything.

You need about 32 GB of RAM plus VRAM combined to start (64 GB for every
model size). NVIDIA GeForce RTX 20/30/40/50 with 12 GB+ VRAM, or AMD Radeon
RX 6800 and newer, are supported. There are no ARM Linux engine builds, so
the package is x86_64 only.

## Install

```bash
paru -S strata-terminal-bin
```

or

```bash
yay -S strata-terminal-bin
```

## Usage

```bash
strata launch        # detect GPU, choose a model, fetch engine and weights
strata serve         # start the local OpenAI/Anthropic-compatible API
strata monitor        # watch engine status
strata update         # update engine and Strata components
strata --help
```

## Notes

- Upstream numbers Terminal and release versions separately: the Terminal
  build version is the package version (`0.1.49.2`), pinned to the Strata
  release (`v0.2.4`) in `_relver`.
- `/usr/bin/strata` conflicts with the unrelated `strata-bin` file manager
  and with the same-project source builds `strata-engine-git` /
  `strata-rocm`; the conflicts list covers all of them. If you want the
  engine built from source for your exact GPU stack, use those packages
  instead.
- Integrity: the source tarball checksum is the one published in the
  release's `install-manifest.txt`.
