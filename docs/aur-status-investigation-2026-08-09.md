# AUR status investigation, 2026-08-09 to 2026-08-10

## Question

Why did package auto-updates stop reaching AUR even when GitHub Actions reported successful runs?

## Findings

- AUR HTTP is currently reachable. `curl -I https://aur.archlinux.org/` returned `HTTP/2 200` on 2026-08-09 and 2026-08-10.
- AUR RPC is currently reachable for existing packages. On 2026-08-09, `rebased-bin` returned `1.1.9-2` and `rebased-zh-bin` returned `1.1.9-1` from `https://aur.archlinux.org/rpc/?v=5&type=info`.
- AUR RPC does not currently list `android-dex-bin`; `https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=android-dex-bin` returned `resultcount: 0`.
- AUR SSH authentication works for the maintainer key. `ssh -T -i ~/.ssh/aur_actions aur@aur.archlinux.org` identified the account as `duanluan`.
- AUR SSH git operations are currently blocked by AUR maintenance. `git ls-remote ssh://aur@aur.archlinux.org/rebased-bin.git HEAD` with the maintainer key returned `The AUR is down due to maintenance. We will be back soon.` on 2026-08-09 and again on 2026-08-10.
- The official Arch status page reports the AUR HTTP monitor as healthy on 2026-08-09 and 2026-08-10: `statusClass: success`, today's ratio `100.000`, and no event feed entries in the prior 30 days. This monitor does not prove the SSH git service is available.
- The official Arch news item "Active AUR malicious packages incident" from 2026-06-12 says users may see issues with creating accounts, pushing package updates, and adopting or creating packages while Arch staff mitigates malicious AUR activity.
- The official Arch news item "Recent service outages" from 2025-08-21 documents infrastructure outages affecting the main website, AUR, and forums, and points users to `status.archlinux.org` for updates.

## Repository-specific evidence

- Recent `aur-auto-update.yml` runs on 2026-08-07 and 2026-08-08 tried to publish changed packages, but each AUR sync failed with `The AUR is down due to maintenance. We will be back soon.`
- The workflow's "Publish to AUR" step records failed packages in the step summary, but it does not exit non-zero after publish failures. As a result, GitHub can show the run as `success` even when no AUR git push succeeded.
- This means "successful workflow run" is not currently reliable proof that AUR received package updates.

## Current interpretation

The evidence points to an AUR-side publishing outage or restriction on the SSH git service, not a local package metadata issue and not a GitHub Actions credential issue. The AUR web and RPC read paths can still look healthy while the git publishing path rejects access with the maintenance message.

## Useful checks

```bash
curl -fsS 'https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=rebased-bin&arg[]=rebased-zh-bin&arg[]=android-dex-bin'

ssh -T -o BatchMode=yes -i ~/.ssh/aur_actions aur@aur.archlinux.org

GIT_SSH_COMMAND='ssh -i ~/.ssh/aur_actions -o IdentitiesOnly=yes -o BatchMode=yes' \
  git ls-remote ssh://aur@aur.archlinux.org/rebased-bin.git HEAD

curl -fsSL 'https://status.archlinux.org/api/getMonitorList/vmM5ruWEAB' \
  | jq -r '.data[] | select(.name=="AUR") | {name,statusClass,ratio:.ratio.ratio,today:(.dailyRatios[-1]),lastDowntime}'
```

## Sources

- AUR: https://aur.archlinux.org/
- AUR RPC: https://aur.archlinux.org/rpc/
- Arch status page: https://status.archlinux.org/
- Arch status page monitor API: https://status.archlinux.org/api/getMonitorList/vmM5ruWEAB
- Arch news, Active AUR malicious packages incident: https://archlinux.org/news/active-aur-malicious-packages-incident/
- Arch news, Recent service outages: https://archlinux.org/news/recent-services-outages/
