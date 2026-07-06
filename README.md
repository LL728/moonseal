# MoonSeal

MoonSeal is a MoonBit release-readiness checker for MoonBit repositories.
It answers a narrow but practical question before a release, competition
submission, or package publish: does this project show enough testing signals
to be treated as ready for review?

The project stays intentionally small. It does not run user test suites,
rewrite source files, or pretend to compute full coverage. Instead, it scans a
repository, classifies packages and test files, counts exported API entries,
collects simple mutation candidates, and produces a stable gate result that can
be consumed by humans or CI logs.

## Problem Background

MoonBit projects already have good build and test commands, but release checks
are often scattered across README habits, local scripts, and manual review.
MoonSeal packages a lightweight pre-release checklist into a single tool:

- find packages that contain source files but no tests
- distinguish blackbox and whitebox tests
- count public declarations from generated interface files
- surface missing project materials such as README, license, or CI workflow
- produce a default PASS/FAIL gate that can be repeated in local checks or CI

## Core Capabilities

- Parse `moon.mod` and `moon.pkg` to discover project structure.
- Classify `.mbt`, `_test.mbt`, and `_wbtest.mbt` files by package.
- Count public API declarations from `pkg.generated.mbti`.
- Build package-level test adequacy summaries.
- Generate stable mutation candidates for boolean, comparison, logical, and
  integer-boundary edits.
- Evaluate a default release gate over tests, package coverage, README,
  license, and CI workflow presence.
- Expose a small CLI with `scan`, `gate`, `mutants`, and `explain`.

## CLI Commands

MoonSeal currently targets the MoonBit JavaScript backend because it needs
filesystem access during repository scanning.

```bash
moon test --target js
moon run --target js cmd/main -- scan <project>
moon run --target js cmd/main -- gate <project>
moon run --target js cmd/main -- mutants <project>
moon run --target js cmd/main -- explain <project>
```

## Minimal Example

```bash
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/untested
moon run --target js cmd/main -- explain fixtures/well_tested
```

## Example Output

`scan fixtures/well_tested` produces a compact report like:

```text
MoonSeal Quality Report v1
project: LL1266/well_tested
version: 0.1.0
source-files: 3
test-files: 3
mutation-candidates: 8
package: internal sources=1 tests=1 public-api=1
package: . sources=2 tests=2 public-api=2
```

`gate fixtures/well_tested` reports `MoonSeal gate: PASS`, while
`gate fixtures/untested` reports `MoonSeal gate: FAIL` together with the failed
checks.

## Public API

- `analyze_project(path : String) -> Result[QualityReport, SealError]`
- `evaluate_gate(report : QualityReport, policy : GatePolicy) -> GateResult`
- `mutation_plan(report : QualityReport) -> Array[MutationCandidate]`
- `render_report(report : QualityReport) -> String`
- `render_gate(result : GateResult) -> String`
- `render_mutants(candidates : Array[MutationCandidate]) -> String`
- `summarize(report : QualityReport) -> String`
- `format_error(err : SealError) -> String`

## Project Limits

- MoonSeal is a structural signal checker, not a replacement for `moon test`.
- The default gate is intentionally simple and readable; it does not try to
  infer semantic coverage.
- Mutation candidates are descriptive only in `v0.1.x`; they are not executed
  automatically.
- Filesystem scanning currently assumes the JS backend.

## Roadmap

- Structured JSON output for CI consumers.
- Configurable gate policies for larger projects.
- Temporary-copy mutation execution with per-candidate test runs.
- Side-by-side trend comparison between two reports.

## Competition And Release Links

- GitLink repository: `https://gitlink.org.cn/LL1266/moonseal`
- GitHub mirror: `https://github.com/LL728/moonseal`
- Mooncakes package: `LL728/moonseal`
- Proposal source: `docs/competition/proposal.md`
- Proposal PDF: `docs/competition/MoonSeal项目申报书.pdf`
- Acceptance checklist: `docs/acceptance-checklist.md`
- Closeout notes: `docs/closeout.md`

## License

Apache-2.0
