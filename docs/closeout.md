# MoonSeal Closeout Notes

## Project identity

- Project name: `MoonSeal：MoonBit 测试充分性与发布质量门禁工具`
- Competition repository: `https://gitlink.org.cn/LL1266/moonseal`
- Public mirror: `https://github.com/LL728/moonseal`
- Mooncakes package: `LL728/moonseal`

## Acceptance refresh

- Pins CI to MoonBit `0.10.3+16975d007` on Ubuntu, macOS, and Windows.
- Uses `moon fmt --check` and `moon info` instead of the removed 0.10.3
  `--deny-warn` flags for formatting and interface generation.
- Makes the gate verify the configured README file and root `LICENSE` file.
- Enforces `min_mutation_score` and `min_coverage` when measurements are
  supplied by `--mutate` and `--coverage`.
- Adds regression coverage for thresholds and missing repository materials.
- Runs dynamic mutation and coverage checks in CI against the passing fixture.

## Verification commands

```bash
moon version --all
moon check --target js
moon fmt --check
moon info
git diff --exit-code
moon test --target js
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/untested
moon run --target js cmd/main -- mutants fixtures/mutation_targets
moon run --target js cmd/main -- explain fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested --mutate --coverage
```

Expected results include 16 passing unit tests, `MoonSeal gate: PASS` for the
well-tested fixture, `MoonSeal gate: FAIL` for the intentionally untested
fixture, stable `MS-` candidate IDs, and a dynamic report containing mutation
and coverage values.

## Known boundaries

- The analyzer and dynamic runner target the JS backend for filesystem and
  child-process access.
- Mutation execution is intentionally one candidate at a time and restores
  the original source after each test run.
- Coverage parsing consumes MoonBit's `moon coverage report -f summary`
  output; the configured threshold applies to its reported total.

## Follow-up links

- Acceptance checklist: `docs/acceptance-checklist.md`
- Submission guide: `docs/submission-guide.md`
- Proposal source: `docs/competition/proposal.md`
