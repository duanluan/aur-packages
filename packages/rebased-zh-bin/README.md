# rebased-zh-bin

`rebased-zh-bin` packages the Chinese language pack generated for Rebased and
depends on `rebased-bin`.

`rebased-bin` copies the installed language pack into the current user's
Rebased data directory before starting Rebased.

## Refresh language pack

```bash
curl -fsSL https://raw.githubusercontent.com/duanluan/shell-scripts/main/prepare-jetbrains-zh-plugin.sh | bash -s -- --jb /opt/jetbrains/intellij-idea-ultimate --ide /opt/rebased
```

## Install

```bash
paru -S rebased-zh-bin
```

Start Rebased with the `rebased` command from `rebased-bin`.
