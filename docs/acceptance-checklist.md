# MoonSeal Acceptance Checklist

## Toolchain and build

- [ ] `moon version --all` reports MoonBit `0.10.3`.
- [ ] `moon check --target js` passes.
- [ ] `moon fmt --check` passes.
- [ ] `moon info` passes and leaves no textual Git diff.
- [ ] `moon test --target js` passes with 16 tests.

## Quality-gate behavior

- [ ] `scan fixtures/well_tested` prints a quality report.
- [ ] `gate fixtures/well_tested` prints `MoonSeal gate: PASS`.
- [ ] `gate fixtures/untested` prints `MoonSeal gate: FAIL`.
- [ ] `mutants fixtures/mutation_targets` prints stable `MS-` candidate IDs.
- [ ] `explain fixtures/well_tested` prints the compact project summary.
- [ ] `gate fixtures/well_tested --mutate --coverage` prints measured mutation
      and coverage values.
- [ ] Policy tests reject mutation and coverage values below configured
      thresholds.
- [ ] Missing README and root LICENSE files are rejected even when the
      `moon.mod` fields still declare them.

## Repository hygiene

- [ ] `README.md` includes installation, environment, usage, and expected
      output steps.
- [ ] `CHANGELOG.md` records the acceptance refresh.
- [ ] The workflow file is under `.github/workflows/ci.yml`.
- [ ] CI runs on Ubuntu, macOS, and Windows with MoonBit 0.10.3 pinned.
- [ ] CI uses read-only contents permission and disables persisted checkout
      credentials.
- [ ] No stale repository URL or outdated mirror path remains in tracked docs.
- [ ] GitLink remote: `https://www.gitlink.org.cn/LL1266/moonseal.git`.
- [ ] GitHub remote: `https://github.com/LL728/moonseal.git`.

## Public submission fields

- [ ] GitLink repository: `https://gitlink.org.cn/LL1266/moonseal`.
- [ ] GitHub mirror: `https://github.com/LL728/moonseal`.
- [ ] Project name: `MoonSeal：MoonBit 测试充分性与发布质量门禁工具`.
- [ ] Proposal PDF: `docs/competition/MoonSeal项目申报书.pdf`.
- [ ] Mooncakes package: `LL728/moonseal`.
