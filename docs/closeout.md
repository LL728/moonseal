# MoonSeal Closeout Notes

## Project Identity

- Project name: `MoonSeal：MoonBit 测试充分性与发布质量门禁工具`
- Competition repository: `https://gitlink.org.cn/LL1266/moonseal`
- Public mirror: `https://github.com/LL728/moonseal`
- Mooncakes package: `LL728/moonseal`

## What This Closeout Refresh Adds

- Unifies repository identity across GitLink, GitHub, README, and competition
  documents.
- Refreshes README and submission-facing documents into a reviewable,
  engineering-style presentation.
- Hardens CI workflow detection so any standard workflow file under
  `.github/workflows/` satisfies the gate.
- Preserves the original approved proposal PDF and updates repository-side
  supporting material instead of regenerating the PDF.

## Verification Commands

```bash
moon info
moon fmt --check
moon test --target js
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/untested
moon run --target js cmd/main -- mutants fixtures/mutation_targets
moon run --target js cmd/main -- explain fixtures/well_tested
```

## Expected Results

- `scan fixtures/well_tested` prints the quality report header and package
  counts.
- `gate fixtures/well_tested` prints `MoonSeal gate: PASS`.
- `gate fixtures/untested` prints `MoonSeal gate: FAIL`.
- `mutants fixtures/mutation_targets` prints stable `MS-` candidate IDs.
- `explain fixtures/well_tested` prints a one-line summary for quick review.

## Known Boundaries

- MoonSeal reports structural test signals; it does not execute a mutation
  campaign or compute line coverage.
- The current implementation targets the JS backend for filesystem access.
- The default gate is intentionally conservative so that its output stays easy
  to read in CI logs and competition reviews.

## Follow-up Links

- Acceptance checklist: `docs/acceptance-checklist.md`
- Submission guide: `docs/submission-guide.md`
- Proposal source: `docs/competition/proposal.md`
