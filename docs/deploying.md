# Deploying

How a change gets from a branch onto the machine: comin watches `main`, CI guards
it, and Renovate keeps the inputs fresh.

## GitOps with comin

Once comin is running, the git repo is the source of truth: push to `main` and the
desktop deploys it within about a minute. Commits that fail to build are not deployed.

Changes go through pull requests (see [CI](#ci) below); the bootstrap's own commit is the
one exception, pushed directly because you're the repo admin. The repo is public, so
comin needs no token. Never commit plaintext secrets (passwords, tokens, SSH keys) here;
use sops (see [Secrets](security.md#secrets-sops--age)).

Tips:
- `comin status` shows what's deployed and what's pending.
- Try risky changes on a testing branch first (see comin's docs on testing branches).
- Updating Nvidia drivers or the kernel needs a reboot, and games may misbehave
  until you do. Avoid pushing those changes mid-session.

## CI

Every push and pull request runs [`.github/workflows/ci.yml`](../.github/workflows/ci.yml),
which evaluates the full system (including home-manager) and every dev shell template.
That catches broken options, removed or renamed packages and typos, which covers nearly
everything that can go wrong in a config. It doesn't do a full build: this desktop
(Nvidia, Steam, CUDA) is too big for a free GitHub runner. Comin still refuses to deploy
anything that fails to build on the machine itself.

`main` is protected: a commit can only land there once **Evaluate NixOS config** has
passed, so comin only ever deploys checked commits. The usual flow:

```sh
git switch -c my-change
# edit, then
git commit -am "Describe the change" && git push
gh pr create --fill        # CI runs on the PR
gh pr merge --squash       # once it's green; comin deploys within a minute
```

As repo admin you can still push straight to `main` in an emergency (the rule isn't
enforced for admins), but then nothing checks the commit first.

### What a lock file PR actually changes

"flake.lock updated" says nothing about what moves, so any PR touching `flake.lock`
gets a **What changed** comment: the kernel, Nvidia and Hyprland versions before and
after, plus every package whose version differs. A PR that moves the kernel or the
Nvidia driver is labelled **needs-reboot**, since those can also interrupt a running
game when comin deploys them.

It reads versions at evaluation time ([`ci/package-versions.nix`](../ci/package-versions.nix)),
so like the rest of CI it never builds. The limit of that: a package rebuilt without a
version change (a patch, a changed dependency) doesn't show up. Use `nvd diff` on the
machine itself for a true closure comparison.

## Updates (Renovate)

[`renovate.json`](../renovate.json) opens update pull requests every Monday morning:

- **flake inputs:** one PR updating `flake.lock` (nixpkgs, home-manager, sops-nix, comin)
- **GitHub Actions:** one PR bumping the workflow action versions

CI evaluates each PR; merge it and comin deploys the update. The Dependency Dashboard
issue Renovate creates lists everything pending and lets you trigger a run early.
Major NixOS release bumps (e.g. `nixos-26.05` → `nixos-26.11`) stay manual: change the
branch names in `flake.nix` and read the release notes first.

Requires the Renovate GitHub App: install it from
[github.com/apps/renovate](https://github.com/apps/renovate) for `nixos-config`.

Mend (who host the app) default an account to **Silent**, which scans the repo but never
opens PRs, branches or the dashboard — it looks exactly like Renovate not running at all.
`"mode": "full"` in `renovate.json` overrides that from the repo, so the setting lives in
git rather than in the Mend portal. Job logs are at
[developer.mend.io](https://developer.mend.io) if a run needs checking.
