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
and package-local warnings. The report also records mutation score, survived
mutants, and the total/file coverage values produced by dynamic checks.

## Gate Policy

The default policy requires at least two test files, at least one test file for
each package that has source files, a README file, a root `LICENSE` file, and a
CI workflow. Optional policy fields enforce minimum mutation score and
coverage after the corresponding dynamic measurements are requested.

## Dynamic checks

MoonSeal reports stable candidate mutation points and can execute them one at
a time against the project's JS test target:

- boolean flips: `true` and `false`.
- comparison boundaries: `<`, `<=`, `>`, `>=`.
- integer boundary changes around `0`.
- logical operator changes between `&&` and `||`.

Each mutated file is restored after its test run. The coverage runner invokes
MoonBit's native coverage commands and parses the summary into the quality
report. Both values feed `evaluate_gate` when non-zero thresholds are present
in `moonseal.json`.
