# MoonSeal

MoonSeal is a MoonBit release-readiness checker and test adequacy gate. It
scans a MoonBit repository, reports package-level testing signals, executes
optional mutation and coverage checks, and applies a configurable release
policy before a package, competition submission, or public release.

## Requirements and installation

MoonSeal targets the MoonBit JavaScript/Node.js backend because it reads the
project filesystem and launches `moon test`. The repository CI is pinned to
MoonBit `0.10.3+16975d007`.

On Linux or macOS:

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"
moon version --all
```

On Windows PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
$env:Path = "$env:USERPROFILE\.moon\bin;$env:Path"
moon version --all
```

The version output should contain MoonBit `0.10.3` (the exact CI build is
`0.10.3+16975d007`). Then clone either public repository:

```bash
git clone https://github.com/LL728/moonseal.git
cd moonseal
```

GitLink competition repository: `https://gitlink.org.cn/LL1266/moonseal`.

## Local verification

Run the fast checks first:

```bash
moon check --target js
moon build --target js
moon fmt --check
moon info
git diff --exit-code
moon test --target js
```

Run the structural examples:

```bash
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/untested
moon run --target js cmd/main -- mutants fixtures/mutation_targets
moon run --target js cmd/main -- explain fixtures/well_tested
moon run --target js cmd/main -- api fixtures/well_tested
```

The well-tested fixture must print `MoonSeal gate: PASS`; the intentionally
untested fixture must print `MoonSeal gate: FAIL`.

Run dynamic mutation and coverage checks when a measured gate is required:

```bash
moon run --target js cmd/main -- scan fixtures/well_tested --mutate --coverage
moon run --target js cmd/main -- gate fixtures/well_tested --mutate --coverage
```

`--mutate` runs the test suite once for each candidate and reports killed and
survived mutants. `--coverage` runs MoonBit coverage and parses its summary.
Both measurements are restored before the command exits.

## Baselines, dashboards, and CI findings

Create a small, reviewable quality baseline after a release-quality scan:

```bash
moon run --target js cmd/main -- snapshot . --output moonseal-baseline.json
moon run --target js cmd/main -- compare . --baseline moonseal-baseline.json
moon run --target js cmd/main -- recommend .
```

The baseline stores stable quality metrics and package summaries. A comparison
fails when project tests, mutation score, coverage, or package test counts
decrease, or when warnings increase. Source/API growth is reported as a
change but is not incorrectly treated as a failure. Use `--mutate` and
`--coverage` with `compare` when the baseline contains measured values.

For a release dashboard or GitHub Code Scanning-compatible report, use the
CLI or library APIs:

```bash
moon run --target js cmd/main -- sarif . --output moonseal.sarif
```

The library APIs `dashboard`, `health_score`, `render_dashboard`, and
`render_sarif` are also available to integrations that already have a
`QualityReport` and `GateResult`.

Public API coverage and historical quality evidence are first-class commands:

```bash
moon run --target js cmd/main -- api .
moon run --target js cmd/main -- trend . --history _build/quality-history.json
```

`api` associates public declarations with package test files and makes
untested symbols visible. `trend` appends a versioned `QualitySnapshot` to a
JSON archive and reports changes in tests, mutation score, coverage, and
warnings. Integrations can normalize external LCOV and Cobertura reports with
`parse_external_coverage`.

## Configurable policy

Create `moonseal.json` in the project being checked:

```json
{
  "min_project_tests": 5,
  "require_package_tests": true,
  "require_tests_for_mutants": true,
  "require_readme": true,
  "require_license": true,
  "require_ci": true,
  "min_mutation_score": 60,
  "min_coverage": 70
}
```

The gate checks the README path declared by `moon.mod`, the root `LICENSE`
file, and a `.github/workflows/*.yml` or `.yaml` workflow. Mutation and
coverage thresholds are enforced against measured values; invoke `gate` with
`--mutate` and/or `--coverage` when those thresholds are non-zero.

## Continuous integration

`.github/workflows/ci.yml` follows the MoonBit community workflow shape. It
runs on Ubuntu, macOS, and Windows, installs the pinned MoonBit 0.10.3
toolchain, checks, builds, checks formatting and generated interfaces, runs tests, and
executes both structural and dynamic quality-gate examples. The workflow has
read-only contents permission and checks out code with persisted credentials
disabled.

## Repository identity

- GitLink: `https://gitlink.org.cn/LL1266/moonseal`
- GitHub mirror: `https://github.com/LL728/moonseal`
- Mooncakes package: `LL728/moonseal`
- Proposal source: `docs/competition/proposal.md`
- Proposal PDF: `docs/competition/MoonSeal项目申报书.pdf`
- Baseline format: `QualitySnapshot` schema version 1; commit the generated
  `moonseal-baseline.json` when a project wants regression protection.
- Acceptance checklist: `docs/acceptance-checklist.md`
- Closeout notes: `docs/closeout.md`

## License

Apache-2.0. See [LICENSE](LICENSE).
