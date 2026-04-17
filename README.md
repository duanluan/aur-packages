# aur-packages

AUR 包发布仓库。

## 目录结构

```text
packages/
  rebased-bin/
    PKGBUILD
    .SRCINFO
    update.sh
    sync-aur.sh
```

每个子目录对应一个 AUR 包。

## 已有包

- `rebased-bin`

## 使用方式

更新某个包的包文件：

```bash
./packages/rebased-bin/update.sh
```

推送某个包到 AUR：

```bash
./packages/rebased-bin/sync-aur.sh
```

## GitHub Actions

当前工作流：

- `.github/workflows/rebased-bin-aur.yml`

需要仓库 secret：

- `AUR_SSH_PRIVATE_KEY`
