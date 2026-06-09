# MoonSeal Architecture

MoonSeal is a MoonBit project quality gate. It reads a project tree, classifies
MoonBit source and test files, builds package-level testing statistics, and
prints a release-oriented gate result.

## Scanner

The scanner walks a project directory with the JavaScript backend. It ignores
build output and dependency caches, then records:

- `moon.mod` metadata.
- every package containing `moon.pkg`.
- source files ending in `.mbt` except test files.
- blackbox tests ending in `_test.mbt`.
- whitebox tests ending in `_wbtest.mbt`.
- public declarations listed in `pkg.generated.mbti`.

## Quality Model

The core report contains project metadata, package quality rows, source files,
test files, import declarations, mutation candidates, and warnings. Package
quality is intentionally direct: source count, test count, public API count,
and package-local warnings.

## Gate Policy

The default policy requires at least two test files, at least one test file for
each package that has source files, a README, a license declaration, and a CI
workflow. These rules are strict enough to catch common release risks but small
enough to be understandable.

## Mutation Candidates

MoonSeal v1 does not edit code. It reports candidate mutation points that a
future runner can apply:

- boolean flips: `true` and `false`.
- comparison boundaries: `<`, `<=`, `>`, `>=`.
- integer boundary changes around `0`.
- logical operator changes between `&&` and `||`.
