# MoonSeal Acceptance Checklist

## Build And Verification

- [ ] `moon info` passes.
- [ ] `moon fmt --check` passes.
- [ ] `moon test --target js` passes.
- [ ] `moon run --target js cmd/main -- scan fixtures/well_tested` prints a
      quality report.
- [ ] `moon run --target js cmd/main -- gate fixtures/well_tested` prints
      `MoonSeal gate: PASS`.
- [ ] `moon run --target js cmd/main -- gate fixtures/untested` prints
      `MoonSeal gate: FAIL`.
- [ ] `moon run --target js cmd/main -- mutants fixtures/mutation_targets`
      prints stable candidate IDs.
- [ ] `moon run --target js cmd/main -- explain fixtures/well_tested` prints
      the compact project summary.

## Repository Hygiene

- [ ] `README.md` describes the tool as a MoonBit test adequacy and release
      quality gate toolkit.
- [ ] `CHANGELOG.md` records the closeout refresh.
- [ ] The workflow file lives under `.github/workflows/` and is readable as a
      normal CI entrypoint.
- [ ] No stale repository URL or outdated mirror path remains in tracked docs.
- [ ] GitLink remote: `https://gitlink.org.cn/LL1266/moonseal.git`.
- [ ] GitHub remote: `https://github.com/LL728/moonseal.git`.

## Public Submission Fields

- [ ] GitLink repository link: `https://gitlink.org.cn/LL1266/moonseal`
- [ ] GitHub mirror link: `https://github.com/LL728/moonseal`
- [ ] Project name:
      `MoonSeal：MoonBit 测试充分性与发布质量门禁工具`
- [ ] Proposal PDF path:
      `docs/competition/MoonSeal项目申报书.pdf`
- [ ] Mooncakes package:
      `LL728/moonseal`
