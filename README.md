# MoonSeal

MoonSeal is a MoonBit release-readiness checker and test adequacy gate tool for MoonBit repositories.
It answers a critical question before a release, competition submission, or package publish: does this project show enough testing signals and quality gate metrics to be treated as ready for review?

## Core Capabilities

- **Project Scanning**: Parse `moon.mod` and `moon.pkg` to discover project structure and classify `.mbt` source, black-box, and white-box test files.
- **Configurable Strategies**: Load and enforce release gate policies from a local `moonseal.json` configuration file.
- **JSON Machine-Readable Output**: Support exporting reports in clean, structured JSON format for CI/CD pipeline automation and machine consumption.
- **Mutation Testing Execution Engine**: Statically extract and dynamically run mutation testing by temporarily applying mutations (boolean flips, comparison boundary shifts, integer boundaries, logical operators) and executing the test suite to calculate a mutation adequacy score.
- **Code Coverage Parser**: Integrate with MoonBit's native coverage tool to run tests with coverage enabled, parse the summary report, and assert minimum coverage requirements.
- **CLI Wrappers for `--deny-warn`**: Provide local wrapper scripts for Linux/macOS and Windows to ensure smooth execution of `--deny-warn` commands in CI environments using newer MoonBit toolchains (0.10.3+).

## CLI Commands

MoonSeal targets the MoonBit JavaScript/Node.js backend because it needs filesystem and child-process access during analysis.

```bash
# Run unit tests
moon test --target js

# Basic scan and release gate check
moon run --target js cmd/main -- scan <project>
moon run --target js cmd/main -- gate <project>

# Run dynamic mutation testing and code coverage checks
moon run --target js cmd/main -- scan <project> --mutate --coverage
moon run --target js cmd/main -- gate <project> --mutate --coverage

# Output machine-readable JSON reports
moon run --target js cmd/main -- scan <project> --json --mutate --coverage
moon run --target js cmd/main -- gate <project> --json --mutate --coverage

# Utility subcommands
moon run --target js cmd/main -- mutants <project> [--json]
moon run --target js cmd/main -- explain <project> [--json]
```

## Configurable Policy (`moonseal.json`)

To customize your project's release quality gate, create a `moonseal.json` in the root of your project:

```json
{
  "min_project_tests": 5,
  "require_package_tests": true,
  "require_tests_for_mutants": true,
  "require_readme": true,
  "require_license": true,
  "require_ci": true,
  "min_mutation_score": 60,
  "min_coverage": 70
}
```

## CLI wrapper for `--deny-warn`

Since MoonBit `0.10.3+` toolchains remove `--deny-warn` from `fmt` and `info`, you can use the wrappers provided in `.github/bin/` to automatically translate these flags locally or in CI:

- **Linux/macOS**: Prepend `.github/bin` to your `PATH` or invoke `.github/bin/moon`.
- **Windows**: Invoke `.github/bin/moon.bat`.

These wrappers automatically map `moon fmt --deny-warn` to `moon fmt --check`, and strip `--deny-warn` from `moon info --deny-warn`, ensuring compatibility and strict warning-to-error gating.

## Competition And Release Links

- GitLink repository: `https://gitlink.org.cn/LL1266/moonseal`
- GitHub mirror: `https://github.com/LL728/moonseal`
- Mooncakes package: `LL728/moonseal`
- Proposal source: `docs/competition/proposal.md`
- Proposal PDF: `docs/competition/MoonSeal项目申报书.pdf`
- Acceptance checklist: `docs/acceptance-checklist.md`
- Closeout notes: `docs/closeout.md`

## License

Apache-2.0
