# Implementation Notes

## Current Version

- Parse `moon.mod` and `moon.pkg`.
- Classify MoonBit source and test files.
- Count public declarations from generated interface files.
- Build package-level testing statistics.
- Generate mutation candidate rows.
- Render scan, gate, mutant, and summary CLI output.

## Next Steps

- Add structured output for CI integration.
- Add configurable gate policies.
- Add a runner that applies one mutation at a time in a temporary copy.
- Add trend comparison between two quality reports.
- Add package-level thresholds for larger projects.
