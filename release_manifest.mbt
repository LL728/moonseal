///|
/// A stable release evidence record for package publication and acceptance.
pub(all) struct ReleaseCheck {
  id : String
  status : String
  detail : String
} derive(Eq)

///|
/// A machine-readable summary of the checks that support a release decision.
pub(all) struct ReleaseManifest {
  schema_version : Int
  project : String
  version : String
  repository : String
  source_files : Int
  test_files : Int
  api_coverage : Int
  gate_passed : Bool
  failed_checks : Int
  checks : Array[ReleaseCheck]
} derive(Eq)

///|
/// Build a release evidence manifest from one project scan.
pub fn make_release_manifest(
  report : QualityReport,
  gate : GateResult,
  api : ApiCoverage,
) -> ReleaseManifest {
  let checks : Array[ReleaseCheck] = []
  add_check(
    checks,
    "tests",
    report.test_files.length() >= 2,
    report.test_files.length().to_string() + " test files discovered",
  )
  add_check(
    checks,
    "readme",
    report.readme.length() > 0,
    if report.readme.length() > 0 {
      "README is present"
    } else {
      "README is missing"
    },
  )
  add_check(
    checks,
    "license",
    report.license.length() > 0,
    if report.license.length() > 0 {
      "license is present"
    } else {
      "license is missing"
    },
  )
  add_check(
    checks,
    "ci",
    !has_warning(report, "missing CI workflow"),
    if has_warning(report, "missing CI workflow") {
      "CI workflow is missing"
    } else {
      "CI workflow is present"
    },
  )
  add_check(
    checks,
    "api",
    api.summary.total == 0 || api.summary.covered == api.summary.total,
    api.summary.covered.to_string() +
    "/" +
    api.summary.total.to_string() +
    " public symbols associated with tests",
  )
  add_check(
    checks,
    "gate",
    gate.passed,
    if gate.passed {
      "quality gate passed"
    } else {
      "quality gate failures=" + gate.failures.length().to_string()
    },
  )
  let failed = count_failed_checks(checks)
  {
    schema_version: 1,
    project: report.name,
    version: report.version,
    repository: report.repository,
    source_files: report.source_files.length(),
    test_files: report.test_files.length(),
    api_coverage: api.summary.percentage,
    gate_passed: gate.passed,
    failed_checks: failed,
    checks,
  }
}

///|
/// Return whether every release evidence check passed.
pub fn manifest_is_ready(manifest : ReleaseManifest) -> Bool {
  manifest.schema_version == 1 && manifest.failed_checks == 0
}

///|
/// Write a release manifest for CI artifacts or a submission archive.
pub fn write_release_manifest(
  path : String,
  manifest : ReleaseManifest,
) -> Result[Unit, String] {
  write_text(path, manifest.to_json().stringify(indent=2) + "\n")
}

///|
/// Read a release manifest produced by `write_release_manifest`.
pub fn read_release_manifest(path : String) -> Result[ReleaseManifest, String] {
  if !fs_exists(path) {
    return Err("release manifest file not found: " + path)
  }
  parse_release_manifest(fs_read(path))
}

///|
/// Parse a release manifest so a downstream publisher can enforce its checks.
pub fn parse_release_manifest(
  input : String,
) -> Result[ReleaseManifest, String] {
  try {
    match @json.parse(input) {
      Object(map) => parse_release_manifest_object(map)
      _ => Err("release manifest must be a JSON object")
    }
  } catch {
    _ => Err("release manifest is not valid JSON")
  }
}

///|
/// Find one named check, returning a failed result when the id is absent.
pub fn manifest_check(manifest : ReleaseManifest, id : String) -> ReleaseCheck {
  for check in manifest.checks {
    if check.id == id {
      return check
    }
  }
  { id, status: "fail", detail: "check is missing from manifest" }
}

///|
/// Return the percentage of evidence checks that passed.
pub fn manifest_pass_rate(manifest : ReleaseManifest) -> Int {
  if manifest.checks.length() == 0 {
    return 0
  }
  let passed = manifest.checks.length() - manifest.failed_checks
  passed * 100 / manifest.checks.length()
}

///|
/// Return failed check ids in stable manifest order.
pub fn manifest_failed_ids(manifest : ReleaseManifest) -> Array[String] {
  let result : Array[String] = []
  for check in manifest.checks {
    if check.status != "pass" {
      result.push(check.id)
    }
  }
  result
}

///|
/// Return a stable one-word status for dashboards and CI annotations.
pub fn manifest_status(manifest : ReleaseManifest) -> String {
  if manifest_is_ready(manifest) {
    "ready"
  } else {
    "blocked"
  }
}

///|
/// Explain failed checks as a comma-separated reviewer hint.
pub fn manifest_failure_summary(manifest : ReleaseManifest) -> String {
  let failed = manifest_failed_ids(manifest)
  if failed.length() == 0 {
    return "none"
  }
  let parts : Array[String] = []
  for id in failed {
    parts.push(id)
  }
  parts.join(", ")
}

///|
/// Return all check ids in the order shown to a reviewer.
pub fn manifest_check_ids(manifest : ReleaseManifest) -> Array[String] {
  let result : Array[String] = []
  for check in manifest.checks {
    result.push(check.id)
  }
  result
}

///|
/// Return whether the manifest contains a named check.
pub fn manifest_has_check(manifest : ReleaseManifest, id : String) -> Bool {
  for check in manifest.checks {
    if check.id == id {
      return true
    }
  }
  false
}

///|
/// Return whether all expected evidence categories are represented.
pub fn manifest_is_complete(manifest : ReleaseManifest) -> Bool {
  manifest.checks.length() >= 6 && manifest_has_check(manifest, "gate")
}

///|
/// Render a compact Markdown table suitable for a release PR description.
pub fn render_release_manifest_markdown(manifest : ReleaseManifest) -> String {
  let out = StringBuilder()
  out.write_string(
    "## MoonSeal release manifest — " +
    (if manifest_is_ready(manifest) { "READY" } else { "NOT READY" }) +
    "\n\n",
  )
  out.write_string("| Check | Status | Detail |\n| --- | --- | --- |\n")
  for check in manifest.checks {
    out.write_string(
      "| " + check.id + " | " + check.status + " | " + check.detail + " |\n",
    )
  }
  out.write_string(
    "\nProject: `" +
    manifest.project +
    "`  \nVersion: `" +
    manifest.version +
    "`  \nAPI coverage: " +
    manifest.api_coverage.to_string() +
    "%  \nPass rate: " +
    manifest_pass_rate(manifest).to_string() +
    "%\n",
  )
  out.to_string()
}

///|
fn parse_release_manifest_object(
  map : Map[String, Json],
) -> Result[ReleaseManifest, String] {
  let schema_version = match required_int(map, "schema_version") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  if schema_version != 1 {
    return Err(
      "unsupported release manifest schema_version: " +
      schema_version.to_string(),
    )
  }
  let project = match required_string(map, "project") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let version = match required_string(map, "version") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let repository = match required_string(map, "repository") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let source_files = match required_int(map, "source_files") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let test_files = match required_int(map, "test_files") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let api_coverage = match required_int(map, "api_coverage") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let gate_passed = match required_bool(map, "gate_passed") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let failed_checks = match required_int(map, "failed_checks") {
    Ok(value) => value
    Err(message) => return Err("release manifest " + message)
  }
  let checks = match map.get("checks") {
    Some(Array(items)) => parse_release_checks(items)
    _ => return Err("release manifest field is missing or not an array: checks")
  }
  Ok({
    schema_version,
    project,
    version,
    repository,
    source_files,
    test_files,
    api_coverage,
    gate_passed,
    failed_checks,
    checks,
  })
}

///|
fn parse_release_checks(items : Array[Json]) -> Array[ReleaseCheck] {
  let checks : Array[ReleaseCheck] = []
  for item in items {
    match item {
      Object(map) => {
        let id = match required_string(map, "id") {
          Ok(value) => value
          Err(message) => abort(message)
        }
        let status = match required_string(map, "status") {
          Ok(value) => value
          Err(message) => abort(message)
        }
        let detail = match required_string(map, "detail") {
          Ok(value) => value
          Err(message) => abort(message)
        }
        checks.push({ id, status, detail })
      }
      _ => abort("release manifest checks must contain objects")
    }
  }
  checks
}

///|
fn required_bool(map : Map[String, Json], key : String) -> Result[Bool, String] {
  match map.get(key) {
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    _ => Err("field is missing or not a boolean: " + key)
  }
}

///|
/// Render an evidence manifest for a human reviewer.
pub fn render_release_manifest(manifest : ReleaseManifest) -> String {
  let out = StringBuilder()
  out.write_string(
    if manifest_is_ready(manifest) {
      "MoonSeal release manifest: READY\n"
    } else {
      "MoonSeal release manifest: NOT READY\n"
    },
  )
  out.write_string("project: " + manifest.project + "\n")
  out.write_string("version: " + manifest.version + "\n")
  out.write_string("repository: " + manifest.repository + "\n")
  out.write_string("source-files: " + manifest.source_files.to_string() + "\n")
  out.write_string("test-files: " + manifest.test_files.to_string() + "\n")
  out.write_string("api-coverage: " + manifest.api_coverage.to_string() + "%\n")
  out.write_string(
    "failed-checks: " + manifest.failed_checks.to_string() + "\n",
  )
  for check in manifest.checks {
    out.write_string(
      "- [" + check.status + "] " + check.id + ": " + check.detail + "\n",
    )
  }
  out.to_string()
}

///|
fn add_check(
  checks : Array[ReleaseCheck],
  id : String,
  passed : Bool,
  detail : String,
) -> Unit {
  checks.push({ id, status: if passed { "pass" } else { "fail" }, detail })
}

///|
fn count_failed_checks(checks : Array[ReleaseCheck]) -> Int {
  let mut failed = 0
  for check in checks {
    if check.status != "pass" {
      failed += 1
    }
  }
  failed
}

///|
pub impl ToJson for ReleaseCheck with fn to_json(self : ReleaseCheck) -> Json {
  Json::object({
    "id": Json::string(self.id),
    "status": Json::string(self.status),
    "detail": Json::string(self.detail),
  })
}

///|
pub impl ToJson for ReleaseManifest with fn to_json(self : ReleaseManifest) -> Json {
  let checks = Array::new()
  for check in self.checks {
    checks.push(check.to_json())
  }
  Json::object({
    "schema_version": Json::number(self.schema_version.to_double()),
    "project": Json::string(self.project),
    "version": Json::string(self.version),
    "repository": Json::string(self.repository),
    "source_files": Json::number(self.source_files.to_double()),
    "test_files": Json::number(self.test_files.to_double()),
    "api_coverage": Json::number(self.api_coverage.to_double()),
    "gate_passed": Json::boolean(self.gate_passed),
    "failed_checks": Json::number(self.failed_checks.to_double()),
    "checks": Json::array(checks),
  })
}
