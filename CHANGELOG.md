# Changelog

## 2026-08-12

- fixed README/LICENSE file-presence checks and enforced mutation/coverage
  policy thresholds
- added regression tests for threshold failures and missing submission files
- reformatted MoonBit sources with 0.10.3 and replaced removed `--deny-warn`
  CI calls with `moon fmt --check`/`moon info`
- pinned three-platform CI to MoonBit `0.10.3+16975d007`
- added dynamic mutation and coverage verification to CI
- expanded README and acceptance documents with installation and reproducible
  verification steps

## 2026-07-06

- refreshed the public project narrative for competition closeout and dual
  repository review
- corrected the GitHub mirror reference to `LL728/moonseal` in repository
  materials
- aligned the Mooncakes publication identity to `LL728/moonseal`
- standardized the CI entrypoint as `.github/workflows/ci.yml`
- relaxed CI workflow detection so any workflow file under
  `.github/workflows/` satisfies the release gate
- added a regression fixture and test for alternate workflow filenames
- added closeout-focused acceptance and submission documentation
