# rebased-zh-bin

`rebased-zh-bin` packages the official Rebased Linux tarball and bundles a Chinese language pack generated for the Rebased IntelliJ build.

The launcher copies the bundled language pack to the current user's Rebased data directory before starting Rebased.

## Refresh language pack

```bash
curl -fsSL https://raw.githubusercontent.com/duanluan/shell-scripts/main/prepare-jetbrains-zh-plugin.sh | bash -s -- --jb /opt/jetbrains/intellij-idea-ultimate --ide /opt/rebased
```

## Install

```bash
paru -S rebased-zh-bin
```

## Launch

```bash
rebased
```
