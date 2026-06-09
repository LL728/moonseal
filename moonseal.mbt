///|
pub(all) struct ModuleMeta {
  name : String
  version : String
  readme : String
  repository : String
  license : String
} derive(Eq)

///|
pub(all) struct ImportInfo {
  target : String
  alias_name : String
  owner : String
} derive(Eq)

///|
pub(all) struct SourceFile {
  path : String
  package_path : String
  is_test : Bool
  digest : String
  mutation_points : Int
} derive(Eq)

///|
pub(all) struct TestFile {
  path : String
  package_path : String
  kind : String
} derive(Eq)

///|
pub(all) struct PackageQuality {
  path : String
  source_count : Int
  test_count : Int
  public_api_count : Int
  warnings : Array[String]
} derive(Eq)

///|
pub(all) struct MutationCandidate {
  id : String
  path : String
  line : Int
  kind : String
  original : String
  replacement : String
} derive(Eq)

///|
pub(all) struct QualityReport {
  name : String
  version : String
  readme : String
  repository : String
  license : String
  packages : Array[PackageQuality]
  imports : Array[ImportInfo]
  source_files : Array[SourceFile]
  test_files : Array[TestFile]
  mutation_candidates : Array[MutationCandidate]
  warnings : Array[String]
} derive(Eq)

///|
pub(all) struct GatePolicy {
  min_project_tests : Int
  require_package_tests : Bool
  require_tests_for_mutants : Bool
  require_readme : Bool
  require_license : Bool
  require_ci : Bool
} derive(Eq)

///|
pub(all) struct GateResult {
  passed : Bool
  failures : Array[String]
  warnings : Array[String]
} derive(Eq)

///|
pub(all) enum SealError {
  MissingProject(String)
  MissingManifest(String)
  FileReadFailed(String)
} derive(Eq)

///|
pub fn default_policy() -> GatePolicy {
  {
    min_project_tests: 2,
    require_package_tests: true,
    require_tests_for_mutants: true,
    require_readme: true,
    require_license: true,
    require_ci: true,
  }
}

///|
pub fn analyze_project(path : String) -> Result[QualityReport, SealError] {
  if !fs_exists(path) {
    return Err(MissingProject(path))
  }
  let manifest_path = join_path(path, "moon.mod")
  if !fs_exists(manifest_path) {
    return Err(MissingManifest(manifest_path))
  }
  let meta = parse_moon_mod(fs_read(manifest_path))
  let files = fs_list_files(path)
  let sources : Array[SourceFile] = []
  let tests : Array[TestFile] = []
  let imports : Array[ImportInfo] = []
  for file in files {
    if file.has_suffix("moon.pkg") {
      let package_path = package_path_of(file)
      for
        item in parse_pkg_imports(package_path, fs_read(join_path(path, file))) {
        imports.push(item)
      }
    } else if file.has_suffix(".mbt") {
      let package_path = package_path_of(file)
      if is_test_file(file) {
        tests.push({
          path: file,
          package_path,
          kind: if file.has_suffix("_wbtest.mbt") {
            "whitebox"
          } else {
            "blackbox"
          },
        })
      } else {
        let content = fs_read(join_path(path, file))
        sources.push({
          path: file,
          package_path,
          is_test: false,
          digest: stable_hash(content),
          mutation_points: collect_mutants_for_file(file, content, 0).length(),
        })
      }
    }
  }
  let mutants = collect_mutation_candidates(path, sources)
  let packages = build_package_quality(path, files, sources, tests)
  let warnings = collect_project_warnings(files, meta, packages)
  Ok({
    name: meta.name,
    version: meta.version,
    readme: meta.readme,
    repository: meta.repository,
    license: meta.license,
    packages,
    imports,
    source_files: sources,
    test_files: tests,
    mutation_candidates: mutants,
    warnings,
  })
}

///|
pub fn parse_moon_mod(input : String) -> ModuleMeta {
  {
    name: quoted_field(input, "name"),
    version: quoted_field(input, "version"),
    readme: quoted_field(input, "readme"),
    repository: quoted_field(input, "repository"),
    license: quoted_field(input, "license"),
  }
}

///|
pub fn parse_pkg_imports(
  package_path : String,
  input : String,
) -> Array[ImportInfo] {
  let imports : Array[ImportInfo] = []
  for raw_line in input.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.length() > 0 && line.contains("\"") && line.contains("@") {
      let target = between(line, "\"", "\"")
      let alias_name = after(line, "@").trim(chars=", \t\r\n").to_owned()
      if target.length() > 0 {
        imports.push({ target, alias_name, owner: package_owner(target) })
      }
    }
  }
  ignore(package_path)
  imports
}

///|
pub fn evaluate_gate(report : QualityReport, policy : GatePolicy) -> GateResult {
  let failures : Array[String] = []
  if report.test_files.length() < policy.min_project_tests {
    failures.push(
      "project has fewer than \{policy.min_project_tests} test files",
    )
  }
  if policy.require_package_tests {
    for pkg in report.packages {
      if pkg.source_count > 0 && pkg.test_count == 0 {
        failures.push("package " + pkg.path + " has source files but no tests")
      }
    }
  }
  if policy.require_tests_for_mutants &&
    report.mutation_candidates.length() > 0 &&
    report.test_files.length() == 0 {
    failures.push("mutation candidates exist but no tests were found")
  }
  if policy.require_readme && !report_has_readme(report) {
    failures.push("README.md is missing")
  }
  if policy.require_license && report.license.length() == 0 {
    failures.push("license field is empty")
  }
  if policy.require_ci && has_warning(report, "missing CI workflow") {
    failures.push("CI workflow is missing")
  }
  { passed: failures.length() == 0, failures, warnings: report.warnings }
}

///|
pub fn mutation_plan(report : QualityReport) -> Array[MutationCandidate] {
  report.mutation_candidates
}

///|
pub fn render_report(report : QualityReport) -> String {
  let out = StringBuilder()
  out.write_string("MoonSeal Quality Report v1\n")
  out.write_string("project: " + report.name + "\n")
  out.write_string("version: " + report.version + "\n")
  out.write_string("source-files: \{report.source_files.length()}\n")
  out.write_string("test-files: \{report.test_files.length()}\n")
  out.write_string(
    "mutation-candidates: \{report.mutation_candidates.length()}\n",
  )
  for pkg in report.packages {
    out.write_string(
      "package: \{pkg.path} sources=\{pkg.source_count} tests=\{pkg.test_count} public-api=\{pkg.public_api_count}\n",
    )
  }
  for warning in report.warnings {
    out.write_string("warning: " + warning + "\n")
  }
  out.to_string()
}

///|
pub fn render_gate(result : GateResult) -> String {
  let out = StringBuilder()
  out.write_string(
    if result.passed {
      "MoonSeal gate: PASS\n"
    } else {
      "MoonSeal gate: FAIL\n"
    },
  )
  for failure in result.failures {
    out.write_string("failure: " + failure + "\n")
  }
  for warning in result.warnings {
    out.write_string("warning: " + warning + "\n")
  }
  out.to_string()
}

///|
pub fn render_mutants(candidates : Array[MutationCandidate]) -> String {
  let out = StringBuilder()
  for candidate in candidates {
    out.write_string(
      "\{candidate.id} \{candidate.kind} \{candidate.path}:\{candidate.line} \{candidate.original} -> \{candidate.replacement}\n",
    )
  }
  out.to_string()
}

///|
pub fn summarize(report : QualityReport) -> String {
  "MoonSeal project=\{report.name} packages=\{report.packages.length()} sources=\{report.source_files.length()} tests=\{report.test_files.length()} mutants=\{report.mutation_candidates.length()} warnings=\{report.warnings.length()}"
}

///|
pub fn has_warning(report : QualityReport, warning : String) -> Bool {
  if warning == "" {
    return report.warnings.length() == 0
  }
  for item in report.warnings {
    if item == warning {
      return true
    }
  }
  false
}

///|
pub fn has_failure(result : GateResult, failure : String) -> Bool {
  for item in result.failures {
    if item == failure {
      return true
    }
  }
  false
}

///|
pub fn format_error(err : SealError) -> String {
  match err {
    MissingProject(path) => "project path not found: " + path
    MissingManifest(path) => "moon.mod not found: " + path
    FileReadFailed(path) => "failed to read file: " + path
  }
}

///|
fn build_package_quality(
  root : String,
  files : Array[String],
  sources : Array[SourceFile],
  tests : Array[TestFile],
) -> Array[PackageQuality] {
  let packages : Array[PackageQuality] = []
  for file in files {
    if file.has_suffix("moon.pkg") {
      let pkg = package_path_of(file)
      let source_count = count_sources_in_package(sources, pkg)
      let test_count = count_tests_in_package(tests, pkg)
      let public_api_count = count_public_api(root, pkg)
      let warnings : Array[String] = []
      if source_count > 0 && test_count == 0 {
        warnings.push("package " + pkg + " has source files but no tests")
      }
      packages.push({
        path: pkg,
        source_count,
        test_count,
        public_api_count,
        warnings,
      })
    }
  }
  packages
}

///|
fn collect_project_warnings(
  files : Array[String],
  meta : ModuleMeta,
  packages : Array[PackageQuality],
) -> Array[String] {
  let warnings : Array[String] = []
  if !array_has(files, "README.md") {
    warnings.push("missing README.md")
  }
  if !array_has(files, "LICENSE") {
    warnings.push("missing LICENSE")
  }
  if !array_has(files, ".github/workflows/ci.yml") {
    warnings.push("missing CI workflow")
  }
  if !meta.name.contains("/") {
    warnings.push("nonstandard package name")
  }
  for pkg in packages {
    for warning in pkg.warnings {
      warnings.push(warning)
    }
  }
  warnings
}

///|
fn collect_mutation_candidates(
  root : String,
  sources : Array[SourceFile],
) -> Array[MutationCandidate] {
  let candidates : Array[MutationCandidate] = []
  for source in sources {
    let content = fs_read(join_path(root, source.path))
    let found = collect_mutants_for_file(
      source.path,
      content,
      candidates.length(),
    )
    for item in found {
      candidates.push(item)
    }
  }
  candidates
}

///|
fn collect_mutants_for_file(
  path : String,
  content : String,
  offset : Int,
) -> Array[MutationCandidate] {
  let candidates : Array[MutationCandidate] = []
  let mut line_no = 0
  for view in content.split("\n") {
    line_no += 1
    let line = view.to_owned()
    if line.contains("true") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "boolean-flip",
          "true",
          "false",
        ),
      )
    }
    if line.contains("false") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "boolean-flip",
          "false",
          "true",
        ),
      )
    }
    if line.contains(">=") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "comparison-boundary",
          ">=",
          ">",
        ),
      )
    } else if line.contains("<=") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "comparison-boundary",
          "<=",
          "<",
        ),
      )
    } else if line.contains(" > ") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "comparison-boundary",
          ">",
          ">=",
        ),
      )
    } else if line.contains(" < ") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "comparison-boundary",
          "<",
          "<=",
        ),
      )
    }
    if line.contains("&&") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "logical-operator",
          "&&",
          "||",
        ),
      )
    }
    if line.contains("||") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "logical-operator",
          "||",
          "&&",
        ),
      )
    }
    if line.contains("= 0") || line.contains(" 0 ") || line.contains(" 0}") {
      candidates.push(
        make_candidate(
          offset + candidates.length() + 1,
          path,
          line_no,
          "integer-boundary",
          "0",
          "1",
        ),
      )
    }
  }
  candidates
}

///|
fn make_candidate(
  n : Int,
  path : String,
  line : Int,
  kind : String,
  original : String,
  replacement : String,
) -> MutationCandidate {
  { id: "MS-" + pad4(n), path, line, kind, original, replacement }
}

///|
fn count_sources_in_package(
  sources : Array[SourceFile],
  package_path : String,
) -> Int {
  let mut count = 0
  for source in sources {
    if source.package_path == package_path {
      count += 1
    }
  }
  count
}

///|
fn count_tests_in_package(
  test_files : Array[TestFile],
  package_path : String,
) -> Int {
  let mut count = 0
  for item in test_files {
    if item.package_path == package_path {
      count += 1
    }
  }
  count
}

///|
fn count_public_api(root : String, package_path : String) -> Int {
  let interface_path = if package_path == "." {
    join_path(root, "pkg.generated.mbti")
  } else {
    join_path(root, package_path + "/pkg.generated.mbti")
  }
  if !fs_exists(interface_path) {
    return 0
  }
  let content = fs_read(interface_path)
  let mut count = 0
  for raw_line in content.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.has_prefix("pub fn ") ||
      line.has_prefix("pub(all) struct ") ||
      line.has_prefix("pub(all) enum ") {
      count += 1
    }
  }
  count
}

///|
fn report_has_readme(report : QualityReport) -> Bool {
  report.readme.length() > 0
}

///|
fn is_test_file(path : String) -> Bool {
  path.has_suffix("_test.mbt") || path.has_suffix("_wbtest.mbt")
}

///|
fn package_path_of(file : String) -> String {
  if file == "moon.pkg" || !file.contains("/") {
    "."
  } else {
    let mut last_slash = -1
    for index in 0..<file.length() {
      if file[index] == '/' {
        last_slash = index
      }
    }
    if last_slash <= 0 {
      "."
    } else {
      file[:last_slash].to_owned()
    }
  }
}

///|
fn quoted_field(input : String, key : String) -> String {
  for raw_line in input.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.has_prefix(key + " ") || line.has_prefix(key + "=") {
      return between(line, "\"", "\"")
    }
  }
  ""
}

///|
fn between(input : String, left : String, right : String) -> String {
  let start = input.find(left)
  match start {
    Some(a) => {
      let rest = input[a + left.length():].to_owned()
      let end = rest.find(right)
      match end {
        Some(b) => rest[:b].to_owned()
        None => ""
      }
    }
    None => ""
  }
}

///|
fn after(input : String, marker : String) -> String {
  let start = input.find(marker)
  match start {
    Some(a) => input[a + marker.length():].to_owned()
    None => ""
  }
}

///|
fn package_owner(target : String) -> String {
  let slash = target.find("/")
  match slash {
    Some(index) => target[:index].to_owned()
    None => target
  }
}

///|
fn stable_hash(input : String) -> String {
  let mut hash = 5381
  for ch in input {
    hash = (hash * 33 + ch.to_int()) % 1000003
  }
  hash.to_string()
}

///|
fn pad4(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn array_has(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn join_path(root : String, child : String) -> String {
  fs_join(root, child)
}

///|
extern "js" fn fs_exists(path : String) -> Bool =
  #|(path) => require("fs").existsSync(path)

///|
extern "js" fn fs_read(path : String) -> String =
  #|(path) => require("fs").readFileSync(path, "utf8")

///|
extern "js" fn fs_join(root : String, child : String) -> String =
  #|(root, child) => require("path").join(root, child)

///|
extern "js" fn fs_list_files(root : String) -> Array[String] =
  #|(root) => {
  #|  const fs = require("fs");
  #|  const path = require("path");
  #|  const out = [];
  #|  function walk(dir, prefix) {
  #|    for (const name of fs.readdirSync(dir).sort()) {
  #|      if (name === ".git" || name === "_build" || name === ".mooncakes" || name === ".repos" || name === "target") continue;
  #|      const full = path.join(dir, name);
  #|      const rel = prefix ? `${prefix}/${name}` : name;
  #|      const stat = fs.statSync(full);
  #|      if (stat.isDirectory()) walk(full, rel);
  #|      else out.push(rel);
  #|    }
  #|  }
  #|  walk(root, "");
  #|  return out;
  #|}
