# Acceptance Checklist

## Build and Test

- [ ] `moon info` passes.
- [ ] `moon fmt --check` passes.
- [ ] `moon test --target js` passes.
- [ ] `moon run --target js cmd/main -- scan fixtures/well_tested` prints a quality report.
- [ ] `moon run --target js cmd/main -- gate fixtures/well_tested` prints `PASS`.
- [ ] `moon run --target js cmd/main -- gate fixtures/untested` prints `FAIL`.
- [ ] `moon run --target js cmd/main -- mutants fixtures/mutation_targets` prints stable candidate IDs.

## Repository Hygiene

- [ ] `README.md` is a normal file with Git mode `100644`.
- [ ] The repository has at least 10 commits.
- [ ] No previous project wording remains in source or docs.
- [ ] The GitLink remote is `https://gitlink.org.cn/LL1266/moonseal.git`.

## Submission Fields

- [ ] GitLink repository link: `https://gitlink.org.cn/LL1266/moonseal`.
- [ ] Project name: `MoonSeal：MoonBit 测试充分性与发布质量门禁工具`.
- [ ] Project proposal upload: `docs/competition/MoonSeal项目申报书.pdf`.
