# MoonSeal Submission Guide

## Repository Links

GitLink:

```text
https://gitlink.org.cn/LL1266/moonseal
```

GitHub mirror:

```text
https://github.com/LL728/moonseal
```

## Project Name

```text
MoonSeal：MoonBit 测试充分性与发布质量门禁工具
```

## Proposal Upload

```text
docs/competition/MoonSeal项目申报书.pdf
```

Editable source:

```text
docs/competition/MoonSeal项目申报书.docx
```

## Reproducible environment

Use MoonBit `0.10.3` or the exact CI build `0.10.3+16975d007`. Install from
the official Unix or PowerShell installer, then verify with:

```bash
moon version --all
moon check --target js
moon fmt --check
moon test --target js
```

The repository workflow at `.github/workflows/ci.yml` repeats these checks on
Ubuntu, macOS, and Windows and also runs the dynamic mutation/coverage gate.

For a maintainable release baseline, run:

```bash
moon run --target js cmd/main -- snapshot . --output moonseal-baseline.json
moon run --target js cmd/main -- compare . --baseline moonseal-baseline.json
moon run --target js cmd/main -- recommend .
```

Commit the baseline only when the measured values were produced with the same
toolchain and command flags. A missing or malformed baseline is reported as an
explicit error; it is never silently replaced by the current scan.

## Acceptance Notes

- Use GitLink as the competition repository link.
- Keep GitHub synchronized as the public mirror repository.
- Keep the Mooncakes package name aligned with `moon.mod`:
  `LL728/moonseal`.
- Keep `README.md`, root `LICENSE`, and `.github/workflows/ci.yml` present in
  every synchronized mirror.
- For a threshold-aware gate, add `moonseal.json` to the project being checked
  and invoke `gate` with `--mutate` and/or `--coverage`.
- Use `docs/closeout.md` as the single entry for the final verification record.
