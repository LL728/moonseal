///|
/// A public symbol discovered in a generated MoonBit interface.
pub(all) struct ApiSymbol {
  name : String
  kind : String
  package_path : String
} derive(Eq)

///|
/// The test evidence associated with one public API symbol.
pub(all) struct ApiCoverageEntry {
  name : String
  kind : String
  package_path : String
  tested : Bool
  test_files : Array[String]
} derive(Eq)

///|
/// Aggregate public-API test coverage.
pub(all) struct ApiCoverageSummary {
  total : Int
  covered : Int
  uncovered : Int
  percentage : Int
} derive(Eq)

///|
/// Public API coverage for a scanned project.
pub(all) struct ApiCoverage {
  entries : Array[ApiCoverageEntry]
  summary : ApiCoverageSummary
} derive(Eq)

///|
/// Associate generated public declarations with test files in the same
/// package. This is intentionally evidence-based: a symbol is covered when a
/// package test mentions its name, making the result explainable and useful
/// for directing stronger behavioral tests.
pub fn analyze_api_coverage(
  root : String,
  report : QualityReport,
) -> ApiCoverage {
  let symbols = collect_api_symbols(root, report)
  let entries : Array[ApiCoverageEntry] = []
  let mut covered = 0
  for symbol in symbols {
    let matching_tests : Array[String] = []
    for test_file in report.test_files {
      if test_file.package_path == symbol.package_path {
        let content = fs_read(join_path(root, test_file.path))
        if content.contains(symbol.name) {
          matching_tests.push(test_file.path)
        }
      }
    }
    let tested = matching_tests.length() > 0
    if tested {
      covered += 1
    }
    entries.push({
      name: symbol.name,
      kind: symbol.kind,
      package_path: symbol.package_path,
      tested,
      test_files: matching_tests,
    })
  }
  let total = entries.length()
  {
    entries,
    summary: {
      total,
      covered,
      uncovered: total - covered,
      percentage: if total == 0 {
        100
      } else {
        covered * 100 / total
      },
    },
  }
}

///|
/// Render API coverage as a concise CI report.
pub fn render_api_coverage(value : ApiCoverage) -> String {
  let out = StringBuilder()
  out.write_string("MoonSeal API Coverage\n")
  out.write_string(
    "summary: covered=" +
    value.summary.covered.to_string() +
    " total=" +
    value.summary.total.to_string() +
    " percentage=" +
    value.summary.percentage.to_string() +
    "%\n",
  )
  for entry in value.entries {
    let status = if entry.tested { "tested" } else { "uncovered" }
    out.write_string(
      "- " +
      status +
      " " +
      entry.package_path +
      "::" +
      entry.name +
      " (" +
      entry.kind +
      ")\n",
    )
    if entry.tested {
      out.write_string(
        "  evidence: " + join_strings(entry.test_files, ", ") + "\n",
      )
    }
  }
  out.to_string()
}

///|
fn collect_api_symbols(
  root : String,
  report : QualityReport,
) -> Array[ApiSymbol] {
  let symbols : Array[ApiSymbol] = []
  let files = fs_list_files(root)
  for file in files {
    if file.has_suffix("pkg.generated.mbti") {
      let package_path = package_path_of(file)
      let content = fs_read(join_path(root, file))
      for raw_line in content.replace_all(old="\r\n", new="\n").split("\n") {
        let line = raw_line.trim().to_owned()
        match api_declaration(line) {
          Some((kind, name)) =>
            if !contains_api_symbol(symbols, package_path, name) {
              symbols.push({ name, kind, package_path })
            }
          None => ()
        }
      }
    }
  }
  ignore(report)
  symbols
}

///|
fn api_declaration(line : String) -> (String, String)? {
  match declaration_after(line, "pub fn ", "function") {
    Some(value) => Some(value)
    None =>
      match declaration_after(line, "pub(all) struct ", "struct") {
        Some(value) => Some(value)
        None =>
          match declaration_after(line, "pub(all) enum ", "enum") {
            Some(value) => Some(value)
            None =>
              match declaration_after(line, "pub trait ", "trait") {
                Some(value) => Some(value)
                None => declaration_after(line, "pub type ", "type")
              }
          }
      }
  }
}

///|
fn declaration_after(
  line : String,
  prefix : String,
  kind : String,
) -> (String, String)? {
  if !line.has_prefix(prefix) {
    return None
  }
  let rest = line[prefix.length():].to_owned()
  let end = first_declaration_end(rest)
  let name = rest[:end].trim().to_owned()
  if name.length() == 0 {
    None
  } else {
    Some((kind, name))
  }
}

///|
fn first_declaration_end(input : String) -> Int {
  let mut end = input.length()
  for index in 0..<input.length() {
    if input[index] == '(' || input[index] == ' ' || input[index] == '{' {
      end = index
      break
    }
  }
  end
}

///|
fn contains_api_symbol(
  symbols : Array[ApiSymbol],
  package_path : String,
  name : String,
) -> Bool {
  for item in symbols {
    if item.package_path == package_path && item.name == name {
      return true
    }
  }
  false
}

///|
fn join_strings(items : Array[String], separator : String) -> String {
  let out = StringBuilder()
  for index in 0..<items.length() {
    if index > 0 {
      out.write_string(separator)
    }
    out.write_string(items[index])
  }
  out.to_string()
}

///|
pub impl ToJson for ApiSymbol with fn to_json(self : ApiSymbol) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "kind": Json::string(self.kind),
    "package_path": Json::string(self.package_path),
  })
}

///|
pub impl ToJson for ApiCoverageEntry with fn to_json(self : ApiCoverageEntry) -> Json {
  let files = Array::new()
  for file in self.test_files {
    files.push(Json::string(file))
  }
  Json::object({
    "name": Json::string(self.name),
    "kind": Json::string(self.kind),
    "package_path": Json::string(self.package_path),
    "tested": Json::boolean(self.tested),
    "test_files": Json::array(files),
  })
}

///|
pub impl ToJson for ApiCoverageSummary with fn to_json(
  self : ApiCoverageSummary,
) -> Json {
  Json::object({
    "total": Json::number(self.total.to_double()),
    "covered": Json::number(self.covered.to_double()),
    "uncovered": Json::number(self.uncovered.to_double()),
    "percentage": Json::number(self.percentage.to_double()),
  })
}

///|
pub impl ToJson for ApiCoverage with fn to_json(self : ApiCoverage) -> Json {
  let entries = Array::new()
  for entry in self.entries {
    entries.push(entry.to_json())
  }
  Json::object({
    "entries": Json::array(entries),
    "summary": self.summary.to_json(),
  })
}
