///|
fn report_ok(path : String) -> @moonseal.QualityReport {
  match @moonseal.analyze_project(path) {
    Ok(report) => report
    Err(err) =>
      abort("unexpected analysis error: " + @moonseal.format_error(err))
  }
}

///|
test "parse moon.mod metadata" {
  let manifest =
    #|name = "LL728/moonseal"
    #|version = "0.1.0"
    #|readme = "README.md"
    #|repository = "https://github.com/LL728/moonseal"
    #|license = "Apache-2.0"
    #|
  let meta = @moonseal.parse_moon_mod(manifest)
  assert_eq(meta.name, "LL728/moonseal")
  assert_eq(meta.version, "0.1.0")
  assert_eq(meta.repository, "https://github.com/LL728/moonseal")
  assert_eq(meta.license, "Apache-2.0")
}

///|
test "parse moon.pkg imports" {
  let pkg =
    #|import {
    #|  "moonbitlang/core/json" @json,
    #|  "LL728/moonseal/internal" @internal,
    #|}
    #|
  let imports = @moonseal.parse_pkg_imports("cmd/main", pkg)
  assert_eq(imports.length(), 2)
  assert_eq(imports[0].target, "moonbitlang/core/json")
  assert_eq(imports[0].alias_name, "json")
  assert_eq(imports[1].owner, "LL728")
}

///|
test "analyze well-tested project" {
  let report = report_ok("fixtures/well_tested")
  assert_eq(report.name, "LL1266/well_tested")
  assert_eq(report.packages.length(), 2)
  assert_eq(report.source_files.length(), 3)
  assert_eq(report.test_files.length(), 3)
  assert_eq(report.mutation_candidates.length(), 8)
  assert_true(@moonseal.has_warning(report, ""))
}

///|
test "gate passes well-tested project" {
  let report = report_ok("fixtures/well_tested")
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  assert_true(gate.passed)
  assert_eq(gate.failures.length(), 0)
  assert_true(@moonseal.render_gate(gate).contains("MoonSeal gate: PASS"))
}

///|
test "gate fails untested project" {
  let report = report_ok("fixtures/untested")
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  assert_false(gate.passed)
  assert_true(
    @moonseal.has_failure(gate, "project has fewer than 2 test files"),
  )
  assert_true(
    @moonseal.has_failure(gate, "package . has source files but no tests"),
  )
}

///|
test "gate fails partially tested package layout" {
  let report = report_ok("fixtures/partial")
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  assert_false(gate.passed)
  assert_true(
    @moonseal.has_failure(
      gate, "package internal has source files but no tests",
    ),
  )
}

///|
test "gate accepts alternate workflow filenames" {
  let report = report_ok("fixtures/alt_workflow")
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  assert_true(gate.passed)
  assert_false(@moonseal.has_warning(report, "missing CI workflow"))
}

///|
test "mutation plan reports stable candidates" {
  let report = report_ok("fixtures/mutation_targets")
  let mutants = @moonseal.mutation_plan(report)
  assert_eq(mutants.length(), 8)
  assert_eq(mutants[0].kind, "boolean-flip")
  assert_eq(mutants[0].replacement, "false")
  assert_true(
    @moonseal.render_mutants(mutants).contains("MS-0001 boolean-flip"),
  )
  assert_true(@moonseal.render_mutants(mutants).contains("comparison-boundary"))
  assert_true(@moonseal.render_mutants(mutants).contains("integer-boundary"))
}

///|
test "summary and report text" {
  let report = report_ok("fixtures/well_tested")
  assert_eq(
    @moonseal.summarize(report),
    "MoonSeal project=LL1266/well_tested packages=2 sources=3 tests=3 mutants=8 warnings=0",
  )
  let text = @moonseal.render_report(report)
  assert_true(text.contains("MoonSeal Quality Report v1"))
  assert_true(text.contains("source-files: 3"))
  assert_true(text.contains("test-files: 3"))
}

///|
test "JSON serialization for report structures" {
  let report = report_ok("fixtures/well_tested")
  let json_str = report.to_json().stringify()
  assert_true(json_str.contains("\"name\":\"LL1266/well_tested\""))
  assert_true(json_str.contains("\"version\":\"0.1.0\""))
  assert_true(json_str.contains("\"packages\""))
}

///|
test "load policy default behavior" {
  let policy = @moonseal.load_policy("fixtures/well_tested")
  let default_p = @moonseal.default_policy()
  assert_eq(policy.min_project_tests, default_p.min_project_tests)
  assert_eq(policy.min_mutation_score, default_p.min_mutation_score)
  assert_eq(policy.min_coverage, default_p.min_coverage)
}
