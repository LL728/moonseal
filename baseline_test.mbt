///|
fn snapshot_ok() -> @moonseal.QualitySnapshot {
  let report = match @moonseal.analyze_project("fixtures/well_tested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  @moonseal.make_snapshot(report)
}

///|
test "snapshot captures release quality metrics" {
  let snapshot = snapshot_ok()
  assert_eq(snapshot.schema_version, 1)
  assert_eq(snapshot.name, "LL1266/well_tested")
  assert_eq(snapshot.source_files, 3)
  assert_eq(snapshot.test_files, 3)
  assert_eq(snapshot.package_count, 2)
  assert_eq(snapshot.mutation_candidates, 8)
}

///|
test "baseline comparison passes when quality does not regress" {
  let baseline = snapshot_ok()
  let current = { ..baseline, version: "0.1.2" }
  let result = @moonseal.compare_snapshot(current, baseline)
  assert_true(result.passed)
  assert_eq(result.regressions.length(), 0)
  assert_true(result.summary.contains("no quality regressions"))
}

///|
test "baseline comparison detects metric regressions" {
  let baseline = {
    ..snapshot_ok(),
    mutation_score: 80,
    coverage_total_percentage: 90,
  }
  let current = {
    ..baseline,
    test_files: 2,
    mutation_score: 50,
    coverage_total_percentage: 60,
  }
  let result = @moonseal.compare_snapshot(current, baseline)
  assert_false(result.passed)
  assert_true(@moonseal.has_regression(result, "test-files"))
  assert_true(@moonseal.has_regression(result, "mutation-score"))
  assert_true(@moonseal.has_regression(result, "coverage"))
  assert_true(@moonseal.render_comparison(result).contains("FAIL"))
}

///|
test "baseline comparison detects package test loss" {
  let baseline = snapshot_ok()
  let packages = baseline.packages.map(fn(item) {
    if item.path == "internal" {
      { ..item, test_count: 0 }
    } else {
      item
    }
  })
  let current = { ..baseline, packages, }
  let result = @moonseal.compare_snapshot(current, baseline)
  assert_false(result.passed)
  assert_true(@moonseal.has_regression(result, "package:internal"))
}

///|
test "snapshot JSON round trip preserves metrics" {
  let original = snapshot_ok()
  let encoded = original.to_json().stringify()
  let decoded = match @moonseal.parse_snapshot(encoded) {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(decoded.schema_version, original.schema_version)
  assert_eq(decoded.name, original.name)
  assert_eq(decoded.version, original.version)
  assert_eq(decoded.source_files, original.source_files)
  assert_eq(decoded.test_files, original.test_files)
  assert_eq(decoded.package_count, original.package_count)
  assert_eq(decoded.mutation_candidates, original.mutation_candidates)
  assert_eq(decoded.packages.length(), original.packages.length())
  assert_eq(decoded.packages[0].path, original.packages[0].path)
  assert_eq(decoded.packages[0].test_count, original.packages[0].test_count)
}

///|
test "snapshot parser rejects missing schema" {
  let parsed = @moonseal.parse_snapshot(
    (
      #|{"name":"demo","version":"0.1.0","source_files":1}
    ),
  )
  match parsed {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("schema_version"))
  }
}

///|
test "recommendations explain actionable quality gaps" {
  let report = match @moonseal.analyze_project("fixtures/untested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let recommendations = @moonseal.recommendations(report)
  assert_true(recommendations.length() >= 3)
  let rendered = @moonseal.render_recommendations(recommendations)
  assert_true(rendered.contains("tests"))
  assert_true(rendered.contains("CI"))
}

///|
test "dashboard exposes score and prioritized risks" {
  let report = match @moonseal.analyze_project("fixtures/untested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let dashboard = @moonseal.dashboard(report)
  assert_true(dashboard.score < 75)
  assert_eq(dashboard.label, "needs-attention")
  assert_true(dashboard.risks.length() >= 3)
  assert_true(@moonseal.render_dashboard(dashboard).contains("health-score"))
}

///|
test "SARIF output turns gate failures into CI findings" {
  let report = match @moonseal.analyze_project("fixtures/untested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  let sarif = @moonseal.render_sarif(report, gate)
  assert_true(sarif.contains("2.1.0"))
  assert_true(sarif.contains("moonseal-gate"))
  assert_true(sarif.contains("package . has source files but no tests"))
}

///|
test "realistic multi-package fixture has complete release materials" {
  let report = match @moonseal.analyze_project("fixtures/realistic_project") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  assert_eq(report.packages.length(), 2)
  assert_eq(report.source_files.length(), 2)
  assert_eq(report.test_files.length(), 2)
  assert_eq(report.warnings.length(), 0)
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  assert_true(gate.passed)
}

///|
test "realistic baseline file is readable and neutral" {
  let baseline = match
    @moonseal.read_snapshot("fixtures/realistic_project/moonseal-baseline.json") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  let report = match @moonseal.analyze_project("fixtures/realistic_project") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let result = @moonseal.compare_snapshot(
    @moonseal.make_snapshot(report),
    baseline,
  )
  assert_true(result.passed)
}
