# DevGuard GitHub Action

Run [DevGuard](https://github.com/AhmedAnbar/devguard) on every push and pull request — audit production-readiness and clean architecture in your CI.

## Quick start

Add this to `.github/workflows/devguard.yml` in your Laravel project:

```yaml
name: DevGuard

on:
  push:
    branches: [main]
  pull_request:

jobs:
  devguard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run DevGuard
        uses: AhmedAnbar/devguard-action@v1
```

That's it — every push runs both the Deploy Readiness scan and the Architecture Enforcer. The build fails on any check failure.

## Inputs

| Input              | Default | Description                                                       |
|--------------------|---------|-------------------------------------------------------------------|
| `tool`             | `all`   | Which tool to run: `deploy`, `architecture`, `env`, `deps`, `all`, or any name. |
| `path`             | `.`     | Project path relative to the workspace.                           |
| `json`             | `false` | Set to `true` to print a JSON report instead of human output.     |
| `fail-on-warning`  | `false` | Set to `true` to fail the build on warnings (not just failures).  |
| `sarif-output`     | `''`    | Path (workspace-relative or absolute) to write a SARIF 2.1.0 file. Pair with `github/codeql-action/upload-sarif` to surface findings as inline PR annotations. |

## Outputs

| Output       | Description                                              |
|--------------|----------------------------------------------------------|
| `exit-code`  | DevGuard's exit code (0 = pass, 1 = fail, 2 = error).    |
| `score`      | Deploy readiness score (0–100). Only when `tool=deploy`. |
| `passed`     | `true` / `false` — overall pass status.                  |

## Examples

### Run only the deploy readiness scan

```yaml
- uses: AhmedAnbar/devguard-action@v1
  with:
    tool: deploy
```

### Strict mode: fail on warnings too

```yaml
- uses: AhmedAnbar/devguard-action@v1
  with:
    tool: deploy
    fail-on-warning: 'true'
```

### Use the score in a follow-up step

```yaml
- name: Deploy gate
  id: gate
  uses: AhmedAnbar/devguard-action@v1
  with:
    tool: deploy
    json: 'true'

- name: Comment score
  if: github.event_name == 'pull_request'
  run: echo "Deploy readiness ${{ steps.gate.outputs.score }}/100"
```

### Run on a sub-directory monorepo

```yaml
- uses: AhmedAnbar/devguard-action@v1
  with:
    path: apps/laravel-api
```

### GitHub Code Scanning — inline PR annotations

```yaml
permissions:
  contents: read
  security-events: write   # required to upload SARIF

steps:
  - uses: actions/checkout@v4

  - name: Run DevGuard
    uses: AhmedAnbar/devguard-action@v1
    with:
      sarif-output: devguard.sarif

  - name: Upload SARIF
    if: always()
    uses: github/codeql-action/upload-sarif@v3
    with:
      sarif_file: devguard.sarif
      category: devguard
```

Once the workflow runs, DevGuard findings appear as red/yellow squiggles on the changed lines of the PR diff and in the repository's **Security → Code scanning** tab. Severities map: failures → `error`, warnings → `warning`. Pass results aren't emitted. The same fingerprint scheme as DevGuard's baseline file is used, so GitHub correctly tracks "same issue across runs" — fix-then-rerun cycles don't re-flag fixed items.

The `if: always()` on the upload step matters: if DevGuard reports failures (which makes the previous step exit non-zero), you still want the SARIF uploaded so reviewers see the findings.

## Versioning

- Pin to a major: `AhmedAnbar/devguard-action@v1` (recommended — gets patches automatically).
- Pin to an exact release: `AhmedAnbar/devguard-action@v1.0.0`.

## License

MIT
