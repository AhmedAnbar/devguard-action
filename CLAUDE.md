# CLAUDE.md

Context for Claude Code when working in this repo. Keep in sync with reality.

---

## What this is

A **Docker-based GitHub Action** that runs the [DevGuard CLI](https://github.com/AhmedAnbar/devguard) against any Laravel project in CI. Intentionally tiny — just an `action.yml`, a `Dockerfile`, and an `entrypoint.sh`.

The actual logic lives in the CLI package on Packagist. This repo is a thin wrapper that makes DevGuard consumable as `uses: AhmedAnbar/devguard-action@v1` from GitHub workflows.

---

## Sibling repo (the actual CLI)

| Repo                                      | Purpose                                            |
|-------------------------------------------|----------------------------------------------------|
| `AhmedAnbar/devguard` (the CLI)           | All the PHP code, tools, checks, rules            |
| `AhmedAnbar/devguard-action` (this repo)  | Docker wrapper for GitHub Actions                  |

Local checkout of the CLI repo: `/Users/ahmedanbar/Documents/dev_guard/`. Read its `CLAUDE.md` for the full architecture context.

---

## Files (whole repo)

```
.
├── action.yml          # Inputs/outputs/branding (Marketplace metadata)
├── Dockerfile          # composer:2 base + global devguard install
├── entrypoint.sh       # Runs devguard, parses JSON for outputs, propagates exit code
├── README.md           # Public-facing usage docs
├── LICENSE             # MIT
└── .gitignore
```

That's the entire repo. There is no test suite here — testing happens in the CLI repo's CI, where two smoke jobs (`action-smoke-pass`, `action-smoke-fail`) consume `@v1` against the CLI's fixtures.

---

## Key design decisions

* **Base image is `composer:2`, not `php:X-alpine`.** The `composer:2` image already has PHP 8.x, composer, bash, and mbstring baked in. Trying to use the bare PHP Alpine image broke v1.0.0 because it doesn't ship `curl` or `mbstring`.
* **Entrypoint deliberately does NOT use `set -e`.** DevGuard's non-zero exit codes are meaningful data (1 = check failed, 2 = tool error). With `set -e`, the script aborts before `EXIT_CODE=$?` runs and the action's outputs never get populated.
* **Single authoritative `--json` run.** The entrypoint runs DevGuard once with `--json` (always), captures the report, then either prints the JSON or re-runs in human mode for the build log. Outputs (`score`, `passed`, `exit-code`) come from the JSON.
* **Best-effort JSON parsing without `jq`.** Uses `grep`/`awk` so we don't add another package to install. Works because DevGuard's JSON has stable shape.
* **Marketplace display name is "DevGuard for Laravel".** GitHub's uniqueness check rejected plain "DevGuard". Display name is decoupled from invocation path — users still type `AhmedAnbar/devguard-action@v1`.

---

## Release flow

```bash
# Make changes, then:
git add Dockerfile entrypoint.sh action.yml
git commit -m "..."
git push origin main

# Tag the immutable exact version
git tag -a v1.x.y -m "DevGuard Action v1.x.y — <summary>"

# Force-update the rolling major tag (THIS is the one users pin to)
git tag -f v1 -m "DevGuard Action v1 (rolling major)"

git push origin v1.x.y
git push --force origin v1
```

The `v1` force-push is **expected** here — it's how the rolling-tag convention works. Users pin `@v1` so they get patches automatically without changing their workflow files. The exact `v1.x.y` tag stays immutable.

After pushing tags, the GitHub Marketplace listing auto-updates within ~30 seconds.

For a new major version (breaking change to inputs/outputs/behavior), create `v2`, then re-create `v2` rolling, etc. Don't reuse `v1` for breaking changes — that violates the action consumer contract.

---

## Testing changes

There's no test suite in this repo. To verify a change works:

1. Push the change to `main` and re-tag `v1` (force).
2. Trigger the CLI repo's CI: `cd ~/Documents/dev_guard && git commit --allow-empty -m "ci: re-trigger" && git push`.
3. Watch https://github.com/AhmedAnbar/devguard/actions — the `action-smoke-pass` and `action-smoke-fail` jobs prove the action works end-to-end.

Local Docker test (rare but useful for fast feedback):
```bash
docker build -t devguard-action .
docker run --rm \
  -v ~/Documents/dev_guard/tests/Fixtures/sample-laravel-app-good:/github/workspace \
  -e GITHUB_WORKSPACE=/github/workspace \
  devguard-action deploy . false false
echo "Exit: $?"   # Expect 0 for good fixture
```

---

## Lessons already learned

1. **`composer:2` over `php:X-alpine`.** The Alpine PHP base image needs a long apk install list (curl, mbstring, ...) and the build is fragile. Use `composer:2` and you get everything in one layer.
2. **No `set -e` in entrypoint.** Exit codes are data, not errors. We need to capture them, not be killed by them.
3. **Marketplace display names must be globally unique.** Short generic names ("DevGuard") are usually taken. Use descriptive ones.
4. **Action consumers pin to `@v1`.** That's why we force-update the rolling tag on every patch. Force-pushing exact-version tags (`v1.0.2`) would be wrong; force-pushing `v1` is correct.
5. **First-run Docker actions are slow** (~60s) because GitHub's runners pull the image fresh. Subsequent runs cache to ~10s. This is the cost of the Docker action style — accept it for the simplicity.
6. **CRITICAL: For 0.x DevGuard versions, the Dockerfile constraint MUST OR every supported minor explicitly.** v1.0.x shipped with `composer require ahmedanbar/devguard:^0.1`, which Composer reads as `>=0.1.0 <0.2.0` (caret pins to minor for 0.x). The action silently froze on v0.1.x for 8 minor releases — users of `@v1` got *only* deploy + architecture, missing env audit, deps audit, fix command, --html, baseline, SARIF, etc. Mirror image of the same trap that bit the CLI's `laravel/prompts` constraint and Ahmed's global `composer require`. Until DevGuard hits 1.0, the constraint must be `^0.1 || ^0.2 || ... || ^0.X`. Fixed in v1.1.0; bump the OR list every time DevGuard ships a new minor.
7. **SARIF wiring (v1.1.0): the SARIF flag is additive — pass it alongside `--json`.** DevGuard ≥0.7.0 supports `--sarif=path` which writes a SARIF 2.1.0 file *without* replacing the stdout format. The entrypoint passes both `--json` (for outputs parsing) and `--sarif=...` (for GitHub Code Scanning) in one invocation. The pretty-print re-run (when `json=false`) deliberately *omits* `--sarif` to avoid double-writing the same file.

---

## Where things are deployed

| Resource             | URL                                                              |
|----------------------|------------------------------------------------------------------|
| GitHub repo          | https://github.com/AhmedAnbar/devguard-action                    |
| GitHub Marketplace   | https://github.com/marketplace/actions/devguard-for-laravel      |
| Sibling CLI repo     | https://github.com/AhmedAnbar/devguard                           |
| Sibling on Packagist | https://packagist.org/packages/ahmedanbar/devguard               |

---

## Current state

- Latest exact tag: **v1.1.0** (Dockerfile version-pin fix + SARIF input)
- Rolling major: **v1** → v1.1.0
- Marketplace: listed as "DevGuard for Laravel"
- CI smoke-tested in the CLI repo on every push (good fixture must pass, bad fixture must exit 1)
- **Major event 2026-04-22**: discovered Dockerfile had been pinned to ahmedanbar/devguard:^0.1 since v1.0.0. Anyone on `@v1` had been missing every feature shipped between v0.2.0 and v0.7.0 — env audit, deps audit, install-hook, fix command, --html, baseline, SARIF. v1.1.0 widens the constraint and bundles the SARIF input.
