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

///|
test "API coverage associates public symbols with package tests" {
  let report = match @moonseal.analyze_project("fixtures/well_tested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let coverage = @moonseal.analyze_api_coverage("fixtures/well_tested", report)
  assert_eq(coverage.entries.length(), 3)
  assert_eq(coverage.summary.total, 3)
  assert_eq(coverage.summary.covered, 3)
  assert_eq(coverage.summary.percentage, 100)
  assert_true(coverage.entries[0].tested)
  assert_true(@moonseal.render_api_coverage(coverage).contains("enabled"))
  assert_true(coverage.to_json().stringify().contains("test_files"))
}

///|
test "API coverage keeps uncovered public symbols visible" {
  let report = match @moonseal.analyze_project("fixtures/mutation_targets") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let coverage = @moonseal.analyze_api_coverage(
    "fixtures/mutation_targets", report,
  )
  assert_true(coverage.summary.total > 0)
  assert_true(coverage.summary.covered < coverage.summary.total)
  assert_true(@moonseal.render_api_coverage(coverage).contains("uncovered"))
}

///|
test "quality history reports directional changes" {
  let first = snapshot_ok()
  let second = {
    ..first,
    version: "0.1.3",
    test_files: 5,
    coverage_total_percentage: 90,
    warning_count: 1,
  }
  let history = @moonseal.make_history([first])
  let appended = @moonseal.append_history(history, second)
  assert_eq(appended.snapshots.length(), 2)
  let trend = @moonseal.summarize_history(appended)
  assert_eq(trend.sample_count, 2)
  assert_eq(trend.test_file_delta, 2)
  assert_eq(trend.coverage_delta, 90)
  assert_eq(trend.warning_delta, 1)
  assert_eq(trend.direction, "mixed")
  assert_true(@moonseal.render_history(trend).contains("test-files"))
}

///|
test "quality history JSON round trip and malformed input" {
  let history = @moonseal.make_history([snapshot_ok()])
  let encoded = history.to_json().stringify()
  let decoded = match @moonseal.parse_history(encoded) {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(decoded.snapshots.length(), 1)
  let malformed = @moonseal.parse_history(
    (
      #|{"schema_version":1,"snapshots":"bad"}
    ),
  )
  match malformed {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("snapshots"))
  }
}

///|
test "coverage adapters normalize LCOV records" {
  let input = "SF:src/lib.mbt\nDA:1,1\nDA:2,0\nDA:3,2\nend_of_record\n"
  let document = match @moonseal.parse_external_coverage(input, "lcov") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(document.total, 3)
  assert_eq(document.covered, 2)
  assert_eq(document.percentage, 66)
  assert_eq(document.files.length(), 1)
  assert_eq(document.files[0].path, "src/lib.mbt")
  assert_eq(document.files[0].covered, 2)
}

///|
test "coverage adapters normalize Cobertura line hits" {
  let input = "<class filename=\"src/lib.mbt\">\n<lines>\n<line number=\"1\" hits=\"1\"/>\n<line number=\"2\" hits=\"0\"/>\n</lines>\n</class>"
  let document = match @moonseal.parse_external_coverage(input, "cobertura") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(document.total, 2)
  assert_eq(document.covered, 1)
  assert_eq(document.percentage, 50)
  assert_true(
    @moonseal.render_external_coverage(document).contains("cobertura"),
  )
}

///|
test "coverage adapters reject unsupported formats and malformed records" {
  let unsupported = @moonseal.parse_external_coverage("", "llvm")
  match unsupported {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("format"))
  }
  let malformed = @moonseal.parse_external_coverage("DA:bad", "lcov")
  match malformed {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("DA"))
  }
}

///|
test "release manifest summarizes a ready project" {
  let report = match @moonseal.analyze_project("fixtures/well_tested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  let api = @moonseal.analyze_api_coverage("fixtures/well_tested", report)
  let manifest = @moonseal.make_release_manifest(report, gate, api)
  assert_true(@moonseal.manifest_is_ready(manifest))
  assert_eq(manifest.schema_version, 1)
  assert_eq(manifest.checks.length(), 6)
  assert_true(@moonseal.render_release_manifest(manifest).contains("READY"))
  assert_true(manifest.to_json().stringify().contains("api_coverage"))
}

///|
test "release manifest preserves failed gate evidence" {
  let report = match @moonseal.analyze_project("fixtures/untested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  let api = @moonseal.analyze_api_coverage("fixtures/untested", report)
  let manifest = @moonseal.make_release_manifest(report, gate, api)
  assert_false(@moonseal.manifest_is_ready(manifest))
  assert_true(manifest.failed_checks > 0)
  assert_true(@moonseal.render_release_manifest(manifest).contains("NOT READY"))
}

///|
test "release manifest JSON round trip preserves checks" {
  let report = match @moonseal.analyze_project("fixtures/well_tested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  let api = @moonseal.analyze_api_coverage("fixtures/well_tested", report)
  let original = @moonseal.make_release_manifest(report, gate, api)
  let decoded = match
    @moonseal.parse_release_manifest(original.to_json().stringify()) {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(decoded.project, original.project)
  assert_eq(decoded.failed_checks, 0)
  assert_eq(decoded.checks.length(), 6)
  assert_eq(@moonseal.manifest_check(decoded, "api").status, "pass")
}

///|
test "release manifest parser rejects missing checks" {
  let malformed = @moonseal.parse_release_manifest(
    (
      #|{"schema_version":1,"project":"demo","version":"0.1.0","repository":"","source_files":1,"test_files":1,"api_coverage":0,"gate_passed":false,"failed_checks":1}
    ),
  )
  match malformed {
    Ok(_) => assert_true(false)
    Err(message) => assert_true(message.contains("checks"))
  }
}

///|
test "release manifest exposes reviewer-friendly summaries" {
  let report = match @moonseal.analyze_project("fixtures/well_tested") {
    Ok(value) => value
    Err(err) => abort(@moonseal.format_error(err))
  }
  let gate = @moonseal.evaluate_gate(report, @moonseal.default_policy())
  let manifest = @moonseal.make_release_manifest(
    report,
    gate,
    @moonseal.analyze_api_coverage("fixtures/well_tested", report),
  )
  assert_eq(@moonseal.manifest_pass_rate(manifest), 100)
  assert_eq(@moonseal.manifest_failed_ids(manifest).length(), 0)
  assert_true(
    @moonseal.render_release_manifest_markdown(manifest).contains("| Check |"),
  )
  assert_eq(@moonseal.manifest_status(manifest), "ready")
  assert_eq(@moonseal.manifest_failure_summary(manifest), "none")
  assert_eq(@moonseal.manifest_check_ids(manifest).length(), 6)
  assert_true(@moonseal.manifest_has_check(manifest, "gate"))
  assert_true(@moonseal.manifest_is_complete(manifest))
}
