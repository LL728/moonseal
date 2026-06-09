# LL1266/moonseal

MoonSeal checks whether a MoonBit project has enough tests to be treated as
ready for release. It scans packages, source files, blackbox tests, whitebox
tests, public interface files, and simple mutation targets, then reports a
quality gate result.

The first version is intentionally small. It does not rewrite source files or
run test suites by itself. Instead, it gives maintainers a stable report they
can read in CI or before a release.

## Features

- Discover MoonBit packages from `moon.pkg`.
- Classify source files, `_test.mbt` files, and `_wbtest.mbt` files.
- Count public API declarations from `pkg.generated.mbti`.
- Report packages that contain source files but no tests.
- Build a mutation candidate list for boolean, comparison, integer, and logical
  operator changes.
- Run a default release gate for test count, package-level tests, README,
  license, and CI workflow presence.

## Quick Start

MoonSeal uses the MoonBit JavaScript backend for filesystem access:

```bash
moon test --target js
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- mutants fixtures/mutation_targets
```

## Public API

- `analyze_project(path : String) -> Result[QualityReport, SealError]`
- `evaluate_gate(report : QualityReport, policy : GatePolicy) -> GateResult`
- `mutation_plan(report : QualityReport) -> Array[MutationCandidate]`
- `render_report(report : QualityReport) -> String`
- `render_gate(result : GateResult) -> String`
- `summarize(report : QualityReport) -> String`
- `format_error(err : SealError) -> String`

## Project Materials

- Proposal source: `docs/competition/proposal.md`
- Proposal PDF: `docs/competition/MoonSeal项目申报书.pdf`
- Proposal DOCX: `docs/competition/MoonSeal项目申报书.docx`
- Design notes: `docs/architecture.md`
- Acceptance checklist: `docs/acceptance-checklist.md`
- Submission guide: `docs/submission-guide.md`

## License

Apache-2.0
