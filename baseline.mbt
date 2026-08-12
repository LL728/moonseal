///|
/// A compact, versioned record of the quality signals that matter in CI.
/// It is deliberately smaller than `QualityReport`, so it remains stable when
/// the analyzer gains more diagnostic detail.
pub(all) struct PackageSnapshot {
  path : String
  source_count : Int
  test_count : Int
  public_api_count : Int
  warning_count : Int
} derive(Eq)

///|
/// A serializable quality baseline suitable for committing to a repository.
pub(all) struct QualitySnapshot {
  schema_version : Int
  name : String
  version : String
  source_files : Int
  test_files : Int
  package_count : Int
  mutation_candidates : Int
  mutants_tested : Int
  mutation_score : Int
  coverage_total_percentage : Int
  warning_count : Int
  packages : Array[PackageSnapshot]
} derive(Eq)

///|
/// One metric changed between a baseline and the current scan.
pub(all) struct SnapshotDelta {
  metric : String
  baseline : Int
  current : Int
  delta : Int
  direction : String
} derive(Eq)

///|
/// A quality regression that should be visible in a pull request.
pub(all) struct SnapshotRegression {
  metric : String
  baseline : Int
  current : Int
  delta : Int
  message : String
} derive(Eq)

///|
/// The result of comparing a scan with a committed quality baseline.
pub(all) struct SnapshotComparison {
  passed : Bool
  baseline_version : String
  current_version : String
  deltas : Array[SnapshotDelta]
  regressions : Array[SnapshotRegression]
  improvements : Array[SnapshotDelta]
  summary : String
} derive(Eq)

///|
/// An actionable hint generated from observable quality signals.
pub(all) struct QualityRecommendation {
  id : String
  priority : String
  title : String
  detail : String
} derive(Eq)

///|
/// Build a baseline from a quality report.
pub fn make_snapshot(report : QualityReport) -> QualitySnapshot {
  let packages : Array[PackageSnapshot] = []
  for pkg in report.packages {
    packages.push({
      path: pkg.path,
      source_count: pkg.source_count,
      test_count: pkg.test_count,
      public_api_count: pkg.public_api_count,
      warning_count: pkg.warnings.length(),
    })
  }
  {
    schema_version: 1,
    name: report.name,
    version: report.version,
    source_files: report.source_files.length(),
    test_files: report.test_files.length(),
    package_count: report.packages.length(),
    mutation_candidates: report.mutation_candidates.length(),
    mutants_tested: report.mutants_tested,
    mutation_score: report.mutation_score,
    coverage_total_percentage: report.coverage_total_percentage,
    warning_count: report.warnings.length(),
    packages,
  }
}

///|
/// Compare quality signals. A decrease in tests, mutation score, coverage, or
/// package-level test count is a regression; more warnings are also treated as
/// a regression. Source and public API changes are reported but are neutral.
pub fn compare_snapshot(
  current : QualitySnapshot,
  baseline : QualitySnapshot,
) -> SnapshotComparison {
  let deltas : Array[SnapshotDelta] = []
  let regressions : Array[SnapshotRegression] = []
  let improvements : Array[SnapshotDelta] = []
  compare_metric(
    "source-files",
    current.source_files,
    baseline.source_files,
    false,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "test-files",
    current.test_files,
    baseline.test_files,
    true,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "packages",
    current.package_count,
    baseline.package_count,
    false,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "mutation-candidates",
    current.mutation_candidates,
    baseline.mutation_candidates,
    false,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "mutation-score",
    current.mutation_score,
    baseline.mutation_score,
    true,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "mutants-tested",
    current.mutants_tested,
    baseline.mutants_tested,
    baseline.mutants_tested > 0,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "coverage",
    current.coverage_total_percentage,
    baseline.coverage_total_percentage,
    true,
    deltas,
    regressions,
    improvements,
  )
  compare_metric(
    "warnings",
    current.warning_count,
    baseline.warning_count,
    false,
    deltas,
    regressions,
    improvements,
  )
  compare_packages(current.packages, baseline.packages, regressions)
  let passed = regressions.length() == 0
  let summary = if passed {
    if improvements.length() == 0 {
      "no quality regressions"
    } else {
      "no quality regressions; improvements=" +
      improvements.length().to_string()
    }
  } else {
    "quality regressions=" + regressions.length().to_string()
  }
  {
    passed,
    baseline_version: baseline.version,
    current_version: current.version,
    deltas,
    regressions,
    improvements,
    summary,
  }
}

///|
/// Return whether a named regression exists.
pub fn has_regression(result : SnapshotComparison, metric : String) -> Bool {
  for item in result.regressions {
    if item.metric == metric {
      return true
    }
  }
  false
}

///|
/// Render a human-readable comparison for CI logs and pull requests.
pub fn render_comparison(result : SnapshotComparison) -> String {
  let out = StringBuilder()
  out.write_string(
    if result.passed {
      "MoonSeal baseline: PASS\n"
    } else {
      "MoonSeal baseline: FAIL\n"
    },
  )
  out.write_string("baseline-version: " + result.baseline_version + "\n")
  out.write_string("current-version: " + result.current_version + "\n")
  out.write_string("summary: " + result.summary + "\n")
  for item in result.regressions {
    out.write_string(
      "regression: " +
      item.metric +
      " " +
      item.baseline.to_string() +
      " -> " +
      item.current.to_string() +
      " (" +
      item.message +
      ")\n",
    )
  }
  for item in result.improvements {
    out.write_string(
      "improvement: " +
      item.metric +
      " " +
      item.baseline.to_string() +
      " -> " +
      item.current.to_string() +
      "\n",
    )
  }
  for item in result.deltas {
    if item.direction == "changed" {
      out.write_string(
        "changed: " +
        item.metric +
        " " +
        item.baseline.to_string() +
        " -> " +
        item.current.to_string() +
        "\n",
      )
    }
  }
  out.to_string()
}

///|
/// Read a baseline JSON document without making the caller depend on JS APIs.
pub fn parse_snapshot(input : String) -> Result[QualitySnapshot, String] {
  try {
    let value = @json.parse(input)
    match value {
      Object(map) => parse_snapshot_object(map)
      _ => Err("baseline must be a JSON object")
    }
  } catch {
    _ => Err("baseline is not valid JSON")
  }
}

///|
/// Read a baseline file produced by `write_snapshot`.
pub fn read_snapshot(path : String) -> Result[QualitySnapshot, String] {
  if !fs_exists(path) {
    return Err("baseline file not found: " + path)
  }
  parse_snapshot(fs_read(path))
}

///|
/// Write a baseline file. The parent directory must already exist.
pub fn write_snapshot(
  path : String,
  snapshot : QualitySnapshot,
) -> Result[Unit, String] {
  write_text(path, snapshot.to_json().stringify(indent=2) + "\n")
}

///|
/// Write a generated integration artifact using the same JS filesystem bridge
/// as snapshots. Keeping this operation in the library makes CLI wrappers and
/// host integrations follow the same error contract.
pub fn write_text(path : String, content : String) -> Result[Unit, String] {
  fs_write(path, content)
  Ok(())
}

///|
/// Generate prioritized remediation advice from a report.
pub fn recommendations(report : QualityReport) -> Array[QualityRecommendation] {
  let result : Array[QualityRecommendation] = []
  if report.test_files.length() < 2 {
    result.push({
      id: "tests-project",
      priority: "high",
      title: "Add project-level tests",
      detail: "Add black-box or white-box tests until the project has at least two test files.",
    })
  }
  for pkg in report.packages {
    if pkg.source_count > 0 && pkg.test_count == 0 {
      result.push({
        id: "tests-package:" + pkg.path,
        priority: "high",
        title: "Test package " + pkg.path,
        detail: "Add a package test file so its source behavior is exercised in CI.",
      })
    }
  }
  if has_warning(report, "missing README.md") {
    result.push({
      id: "docs-readme",
      priority: "high",
      title: "Document installation and usage",
      detail: "Add the README declared by moon.mod, including environment, commands, and expected output.",
    })
  }
  if has_warning(report, "missing LICENSE") {
    result.push({
      id: "legal-license",
      priority: "high",
      title: "Add an open-source license",
      detail: "Place a complete LICENSE file at the project root and keep it synchronized with moon.mod.",
    })
  }
  if has_warning(report, "missing CI workflow") {
    result.push({
      id: "ci-workflow",
      priority: "high",
      title: "Add a reproducible CI workflow",
      detail: "Run MoonBit checks, formatting, generated interfaces, and tests on the supported platforms.",
    })
  }
  if report.mutation_candidates.length() > 0 && report.mutation_score == 0 {
    result.push({
      id: "mutation-baseline",
      priority: "medium",
      title: "Measure mutation adequacy",
      detail: "Run the gate with --mutate and use survived mutants to add boundary assertions.",
    })
  }
  if report.coverage_total_percentage == 0 {
    result.push({
      id: "coverage-baseline",
      priority: "medium",
      title: "Measure code coverage",
      detail: "Run the gate with --coverage and set a project-appropriate minimum in moonseal.json.",
    })
  }
  if report.warnings.length() == 0 && report.mutation_candidates.length() == 0 {
    result.push({
      id: "maintain-regression",
      priority: "low",
      title: "Maintain a quality baseline",
      detail: "Commit a snapshot and compare it in CI so future changes cannot silently reduce quality.",
    })
  }
  result
}

///|
/// Render remediation advice for terminal output.
pub fn render_recommendations(items : Array[QualityRecommendation]) -> String {
  if items.length() == 0 {
    return "MoonSeal recommendations: none\n"
  }
  let out = StringBuilder()
  out.write_string("MoonSeal recommendations:\n")
  for item in items {
    out.write_string(
      "- [" + item.priority + "] " + item.title + ": " + item.detail + "\n",
    )
  }
  out.to_string()
}

///|
/// Return a small health score for dashboards. The score is explainable and
/// intentionally does not replace the strict gate.
pub fn health_score(report : QualityReport) -> Int {
  let mut score = 100
  if report.test_files.length() == 0 {
    score -= 25
  } else if report.test_files.length() < 2 {
    score -= 10
  }
  for pkg in report.packages {
    if pkg.source_count > 0 && pkg.test_count == 0 {
      score -= 15
    }
  }
  if report.readme.length() == 0 {
    score -= 10
  }
  if report.license.length() == 0 {
    score -= 10
  }
  if has_warning(report, "missing CI workflow") {
    score -= 15
  }
  if report.mutation_candidates.length() > 0 && report.mutation_score == 0 {
    score -= 10
  }
  if score < 0 {
    0
  } else {
    score
  }
}

///|
/// Provide a stable label for simple dashboards.
pub fn health_label(score : Int) -> String {
  if score >= 90 {
    "excellent"
  } else if score >= 75 {
    "good"
  } else if score >= 50 {
    "needs-attention"
  } else {
    "critical"
  }
}

///|
fn compare_metric(
  metric : String,
  current : Int,
  baseline : Int,
  lower_is_regression : Bool,
  deltas : Array[SnapshotDelta],
  regressions : Array[SnapshotRegression],
  improvements : Array[SnapshotDelta],
) -> Unit {
  let delta = current - baseline
  let direction = if delta == 0 { "unchanged" } else { "changed" }
  if delta != 0 {
    let item = { metric, baseline, current, delta, direction }
    deltas.push(item)
    let bad = if lower_is_regression {
      delta < 0
    } else {
      metric == "warnings" && delta > 0
    }
    if bad {
      regressions.push({
        metric,
        baseline,
        current,
        delta,
        message: if metric == "warnings" {
          "warning count increased"
        } else {
          "quality metric decreased"
        },
      })
    } else if lower_is_regression && delta > 0 {
      improvements.push(item)
    }
  }
}

///|
fn compare_packages(
  current : Array[PackageSnapshot],
  baseline : Array[PackageSnapshot],
  regressions : Array[SnapshotRegression],
) -> Unit {
  for old_package in baseline {
    match find_package(current, old_package.path) {
      Some(new_package) => {
        if old_package.source_count > 0 &&
          old_package.test_count > 0 &&
          new_package.test_count < old_package.test_count {
          let delta = new_package.test_count - old_package.test_count
          regressions.push({
            metric: "package:" + old_package.path,
            baseline: old_package.test_count,
            current: new_package.test_count,
            delta,
            message: "package test count decreased",
          })
        }
        if new_package.warning_count > old_package.warning_count {
          let delta = new_package.warning_count - old_package.warning_count
          regressions.push({
            metric: "package-warnings:" + old_package.path,
            baseline: old_package.warning_count,
            current: new_package.warning_count,
            delta,
            message: "package warnings increased",
          })
        }
      }
      None =>
        regressions.push({
          metric: "package:" + old_package.path,
          baseline: old_package.source_count,
          current: 0,
          delta: 0 - old_package.source_count,
          message: "package disappeared",
        })
    }
  }
}

///|
fn find_package(
  packages : Array[PackageSnapshot],
  path : String,
) -> PackageSnapshot? {
  for pkg in packages {
    if pkg.path == path {
      return Some(pkg)
    }
  }
  None
}

///|
fn parse_snapshot_object(
  map : Map[String, Json],
) -> Result[QualitySnapshot, String] {
  let schema_version = match required_int(map, "schema_version") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if schema_version != 1 {
    return Err(
      "unsupported baseline schema_version: " + schema_version.to_string(),
    )
  }
  let name = match required_string(map, "name") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let version = match required_string(map, "version") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_files = match required_int(map, "source_files") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let test_files = match required_int(map, "test_files") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let package_count = match required_int(map, "package_count") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mutation_candidates = match required_int(map, "mutation_candidates") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mutants_tested = match required_int(map, "mutants_tested") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mutation_score = match required_int(map, "mutation_score") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let coverage_total_percentage = match
    required_int(map, "coverage_total_percentage") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let warning_count = match required_int(map, "warning_count") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let packages = match required_packages(map, "packages") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    schema_version,
    name,
    version,
    source_files,
    test_files,
    package_count,
    mutation_candidates,
    mutants_tested,
    mutation_score,
    coverage_total_percentage,
    warning_count,
    packages,
  })
}

///|
fn required_string(
  map : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match map.get(key) {
    Some(String(value)) => Ok(value)
    _ => Err("baseline field is missing or not a string: " + key)
  }
}

///|
fn required_int(map : Map[String, Json], key : String) -> Result[Int, String] {
  match map.get(key) {
    Some(Number(value, ..)) => Ok(value.to_int())
    _ => Err("baseline field is missing or not an integer: " + key)
  }
}

///|
fn required_packages(
  map : Map[String, Json],
  key : String,
) -> Result[Array[PackageSnapshot], String] {
  match map.get(key) {
    Some(Array(items)) => {
      let packages : Array[PackageSnapshot] = []
      for item in items {
        match item {
          Object(package_map) => {
            let path = match required_string(package_map, "path") {
              Ok(value) => value
              Err(message) => return Err(message)
            }
            let source_count = match required_int(package_map, "source_count") {
              Ok(value) => value
              Err(message) => return Err(message)
            }
            let test_count = match required_int(package_map, "test_count") {
              Ok(value) => value
              Err(message) => return Err(message)
            }
            let public_api_count = match
              required_int(package_map, "public_api_count") {
              Ok(value) => value
              Err(message) => return Err(message)
            }
            let warning_count = match
              required_int(package_map, "warning_count") {
              Ok(value) => value
              Err(message) => return Err(message)
            }
            packages.push({
              path,
              source_count,
              test_count,
              public_api_count,
              warning_count,
            })
          }
          _ => return Err("baseline packages must contain objects")
        }
      }
      Ok(packages)
    }
    _ => Err("baseline field is missing or not an array: " + key)
  }
}

///|
pub impl ToJson for PackageSnapshot with fn to_json(self : PackageSnapshot) -> Json {
  Json::object({
    "path": Json::string(self.path),
    "source_count": Json::number(self.source_count.to_double()),
    "test_count": Json::number(self.test_count.to_double()),
    "public_api_count": Json::number(self.public_api_count.to_double()),
    "warning_count": Json::number(self.warning_count.to_double()),
  })
}

///|
pub impl ToJson for QualitySnapshot with fn to_json(self : QualitySnapshot) -> Json {
  let packages = Array::new()
  for pkg in self.packages {
    packages.push(pkg.to_json())
  }
  Json::object({
    "schema_version": Json::number(self.schema_version.to_double()),
    "name": Json::string(self.name),
    "version": Json::string(self.version),
    "source_files": Json::number(self.source_files.to_double()),
    "test_files": Json::number(self.test_files.to_double()),
    "package_count": Json::number(self.package_count.to_double()),
    "mutation_candidates": Json::number(self.mutation_candidates.to_double()),
    "mutants_tested": Json::number(self.mutants_tested.to_double()),
    "mutation_score": Json::number(self.mutation_score.to_double()),
    "coverage_total_percentage": Json::number(
      self.coverage_total_percentage.to_double(),
    ),
    "warning_count": Json::number(self.warning_count.to_double()),
    "packages": Json::array(packages),
  })
}

///|
pub impl ToJson for SnapshotDelta with fn to_json(self : SnapshotDelta) -> Json {
  Json::object({
    "metric": Json::string(self.metric),
    "baseline": Json::number(self.baseline.to_double()),
    "current": Json::number(self.current.to_double()),
    "delta": Json::number(self.delta.to_double()),
    "direction": Json::string(self.direction),
  })
}

///|
pub impl ToJson for SnapshotRegression with fn to_json(
  self : SnapshotRegression,
) -> Json {
  Json::object({
    "metric": Json::string(self.metric),
    "baseline": Json::number(self.baseline.to_double()),
    "current": Json::number(self.current.to_double()),
    "delta": Json::number(self.delta.to_double()),
    "message": Json::string(self.message),
  })
}

///|
pub impl ToJson for SnapshotComparison with fn to_json(
  self : SnapshotComparison,
) -> Json {
  let deltas = Array::new()
  for item in self.deltas {
    deltas.push(item.to_json())
  }
  let regressions = Array::new()
  for item in self.regressions {
    regressions.push(item.to_json())
  }
  let improvements = Array::new()
  for item in self.improvements {
    improvements.push(item.to_json())
  }
  Json::object({
    "passed": Json::boolean(self.passed),
    "baseline_version": Json::string(self.baseline_version),
    "current_version": Json::string(self.current_version),
    "deltas": Json::array(deltas),
    "regressions": Json::array(regressions),
    "improvements": Json::array(improvements),
    "summary": Json::string(self.summary),
  })
}

///|
pub impl ToJson for QualityRecommendation with fn to_json(
  self : QualityRecommendation,
) -> Json {
  Json::object({
    "id": Json::string(self.id),
    "priority": Json::string(self.priority),
    "title": Json::string(self.title),
    "detail": Json::string(self.detail),
  })
}
