# rebased-bin

生成并同步 `rebased-bin` 到 AUR。

## 本地更新包文件

```bash
./packages/rebased-bin/update.sh
```

## 本地推送到 AUR

前提：

- AUR 账号已添加对应 SSH 公钥
- 当前环境可直接连 `aur.archlinux.org:22`

执行：

```bash
./packages/rebased-bin/sync-aur.sh
```

## GitHub Actions 自动更新

工作流文件：

- `.github/workflows/rebased-bin-aur.yml`

需要在 GitHub 仓库 `duanluan/aur-packages` 配置 secret：

- `AUR_SSH_PRIVATE_KEY`

建议使用一个专门给 AUR 的私钥，并把对应公钥加到 AUR 账号设置里。
