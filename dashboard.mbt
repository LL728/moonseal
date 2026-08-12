///|
/// A compact dashboard model for release pages and CI summaries.
pub(all) struct QualityDashboard {
  project : String
  version : String
  score : Int
  label : String
  source_files : Int
  test_files : Int
  package_count : Int
  mutation_candidates : Int
  mutation_score : Int
  coverage_percentage : Int
  warning_count : Int
  recommendation_count : Int
  risks : Array[String]
} derive(Eq)

///|
/// Create a dashboard without running any additional commands.
pub fn dashboard(report : QualityReport) -> QualityDashboard {
  let risks : Array[String] = []
  if report.test_files.length() == 0 {
    risks.push("no project tests")
  } else if report.test_files.length() < 2 {
    risks.push("fewer than two test files")
  }
  for pkg in report.packages {
    if pkg.source_count > 0 && pkg.test_count == 0 {
      risks.push("untested package: " + pkg.path)
    }
  }
  if has_warning(report, "missing README.md") {
    risks.push("README is missing")
  }
  if has_warning(report, "missing LICENSE") {
    risks.push("LICENSE is missing")
  }
  if has_warning(report, "missing CI workflow") {
    risks.push("CI workflow is missing")
  }
  if report.mutation_candidates.length() > 0 && report.mutation_score == 0 {
    risks.push("mutation score has not been measured")
  }
  if report.coverage_total_percentage == 0 {
    risks.push("coverage has not been measured")
  }
  let items = recommendations(report)
  let score = health_score(report)
  {
    project: report.name,
    version: report.version,
    score,
    label: health_label(score),
    source_files: report.source_files.length(),
    test_files: report.test_files.length(),
    package_count: report.packages.length(),
    mutation_candidates: report.mutation_candidates.length(),
    mutation_score: report.mutation_score,
    coverage_percentage: report.coverage_total_percentage,
    warning_count: report.warnings.length(),
    recommendation_count: items.length(),
    risks,
  }
}

///|
/// Render a dashboard for release notes or a job summary.
pub fn render_dashboard(value : QualityDashboard) -> String {
  let out = StringBuilder()
  out.write_string("MoonSeal Quality Dashboard\n")
  out.write_string("project: " + value.project + "\n")
  out.write_string("version: " + value.version + "\n")
  out.write_string("health-score: " + value.score.to_string() + "/100\n")
  out.write_string("health-label: " + value.label + "\n")
  out.write_string("source-files: " + value.source_files.to_string() + "\n")
  out.write_string("test-files: " + value.test_files.to_string() + "\n")
  out.write_string("packages: " + value.package_count.to_string() + "\n")
  out.write_string(
    "mutation: candidates=" +
    value.mutation_candidates.to_string() +
    " score=" +
    value.mutation_score.to_string() +
    "%\n",
  )
  out.write_string("coverage: " + value.coverage_percentage.to_string() + "%\n")
  out.write_string("warnings: " + value.warning_count.to_string() + "\n")
  out.write_string(
    "recommendations: " + value.recommendation_count.to_string() + "\n",
  )
  if value.risks.length() == 0 {
    out.write_string("risks: none\n")
  } else {
    for risk in value.risks {
      out.write_string("risk: " + risk + "\n")
    }
  }
  out.to_string()
}

///|
/// Emit SARIF 2.1.0 so GitHub code scanning or another CI viewer can display
/// MoonSeal warnings and gate failures as structured findings.
pub fn render_sarif(report : QualityReport, gate : GateResult) -> String {
  let results = Array::new()
  for warning in report.warnings {
    results.push(sarif_result("moonseal-warning", "warning", warning))
  }
  for failure in gate.failures {
    results.push(sarif_result("moonseal-gate", "error", failure))
  }
  let rules = Array::new()
  rules.push(sarif_rule("moonseal-warning", "Repository quality warning"))
  rules.push(sarif_rule("moonseal-gate", "Release quality gate failure"))
  let rule_map = Json::object({
    "name": Json::string("MoonSeal"),
    "informationUri": Json::string("https://github.com/LL728/moonseal"),
    "rules": Json::array(rules),
  })
  let run = Json::object({
    "tool": Json::object({ "driver": rule_map }),
    "results": Json::array(results),
    "properties": Json::object({
      "project": Json::string(report.name),
      "version": Json::string(report.version),
      "passed": Json::boolean(gate.passed),
    }),
  })
  Json::object({
    "$schema": Json::string("https://json.schemastore.org/sarif-2.1.0.json"),
    "version": Json::string("2.1.0"),
    "runs": Json::array([run]),
  }).stringify(indent=2)
}

///|
fn sarif_rule(id : String, name : String) -> Json {
  Json::object({
    "id": Json::string(id),
    "name": Json::string(name),
    "shortDescription": Json::object({ "text": Json::string(name) }),
  })
}

///|
fn sarif_result(id : String, level : String, message : String) -> Json {
  Json::object({
    "ruleId": Json::string(id),
    "level": Json::string(level),
    "message": Json::object({ "text": Json::string(message) }),
  })
}

///|
/// Serialize a dashboard for small status badges and web clients.
pub impl ToJson for QualityDashboard with fn to_json(self : QualityDashboard) -> Json {
  let risks = Array::new()
  for item in self.risks {
    risks.push(Json::string(item))
  }
  Json::object({
    "project": Json::string(self.project),
    "version": Json::string(self.version),
    "score": Json::number(self.score.to_double()),
    "label": Json::string(self.label),
    "source_files": Json::number(self.source_files.to_double()),
    "test_files": Json::number(self.test_files.to_double()),
    "package_count": Json::number(self.package_count.to_double()),
    "mutation_candidates": Json::number(self.mutation_candidates.to_double()),
    "mutation_score": Json::number(self.mutation_score.to_double()),
    "coverage_percentage": Json::number(self.coverage_percentage.to_double()),
    "warning_count": Json::number(self.warning_count.to_double()),
    "recommendation_count": Json::number(self.recommendation_count.to_double()),
    "risks": Json::array(risks),
  })
}
