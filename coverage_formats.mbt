///|
/// A normalized report from a portable coverage interchange format.
pub(all) struct ExternalCoverage {
  format : String
  total : Int
  covered : Int
  percentage : Int
  files : Array[FileCoverage]
} derive(Eq)

///|
/// Parse LCOV or Cobertura line coverage into MoonSeal's common model.
pub fn parse_external_coverage(
  input : String,
  format : String,
) -> Result[ExternalCoverage, String] {
  match format.to_lower() {
    "lcov" => parse_lcov(input)
    "cobertura" => parse_cobertura(input)
    _ => Err("unsupported coverage format: " + format)
  }
}

///|
/// Render normalized external coverage for a CI log.
pub fn render_external_coverage(report : ExternalCoverage) -> String {
  let out = StringBuilder()
  out.write_string("MoonSeal external coverage: " + report.format + "\n")
  out.write_string(
    "total: " +
    report.covered.to_string() +
    "/" +
    report.total.to_string() +
    " (" +
    report.percentage.to_string() +
    "%)\n",
  )
  for file in report.files {
    out.write_string(
      "- " +
      file.path +
      ": " +
      file.covered.to_string() +
      "/" +
      file.total.to_string() +
      " (" +
      file.percentage.to_string() +
      "%)\n",
    )
  }
  out.to_string()
}

///|
fn parse_lcov(input : String) -> Result[ExternalCoverage, String] {
  let files : Array[FileCoverage] = []
  let mut current_path = ""
  let mut current_total = 0
  let mut current_covered = 0
  let mut total = 0
  let mut covered = 0
  for raw in input.replace_all(old="\r\n", new="\n").split("\n") {
    let line = raw.to_owned().trim().to_owned()
    if line.has_prefix("SF:") {
      if current_path.length() > 0 {
        files.push(
          make_external_file(current_path, current_covered, current_total),
        )
      }
      current_path = line[3:].to_owned()
      current_total = 0
      current_covered = 0
    } else if line.has_prefix("DA:") {
      let fields = line[3:].split(",").map(fn(s) { s.to_owned() }).to_array()
      if fields.length() < 2 {
        return Err("LCOV DA record must contain line and hit count")
      }
      let hits = parse_int(fields[1])
      if !all_digits(fields[1]) {
        return Err("LCOV DA hit count is not an integer: " + fields[1])
      }
      current_total += 1
      if hits > 0 {
        current_covered += 1
      }
    } else if line == "end_of_record" && current_path.length() > 0 {
      files.push(
        make_external_file(current_path, current_covered, current_total),
      )
      total += current_total
      covered += current_covered
      current_path = ""
    }
  }
  if current_path.length() > 0 {
    files.push(make_external_file(current_path, current_covered, current_total))
    total += current_total
    covered += current_covered
  }
  Ok({
    format: "lcov",
    total,
    covered,
    percentage: coverage_percentage(covered, total),
    files,
  })
}

///|
fn parse_cobertura(input : String) -> Result[ExternalCoverage, String] {
  let files : Array[FileCoverage] = []
  let mut current_path = ""
  let mut current_total = 0
  let mut current_covered = 0
  for raw in input.replace_all(old="\r\n", new="\n").split("\n") {
    let line = raw.to_owned()
    if line.contains("<class") && line.contains("filename=") {
      current_path = attribute(line, "filename")
      current_total = 0
      current_covered = 0
    }
    if line.contains("<line") && line.contains("hits=") {
      let hits_text = attribute(line, "hits")
      if hits_text.length() == 0 || !all_digits(hits_text) {
        return Err("Cobertura line hits is not an integer")
      }
      current_total += 1
      if parse_int(hits_text) > 0 {
        current_covered += 1
      }
    }
    if line.contains("</class>") && current_path.length() > 0 {
      files.push(
        make_external_file(current_path, current_covered, current_total),
      )
      current_path = ""
    }
  }
  if current_path.length() > 0 {
    files.push(make_external_file(current_path, current_covered, current_total))
  }
  let mut total = 0
  let mut covered = 0
  for file in files {
    total += file.total
    covered += file.covered
  }
  Ok({
    format: "cobertura",
    total,
    covered,
    percentage: coverage_percentage(covered, total),
    files,
  })
}

///|
fn make_external_file(
  path : String,
  covered : Int,
  total : Int,
) -> FileCoverage {
  { path, covered, total, percentage: coverage_percentage(covered, total) }
}

///|
fn coverage_percentage(covered : Int, total : Int) -> Int {
  if total == 0 {
    100
  } else {
    covered * 100 / total
  }
}

///|
fn all_digits(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  for ch in value {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn attribute(line : String, name : String) -> String {
  let marker = name + "=\""
  match line.find(marker) {
    Some(start) => {
      let value_start = start + marker.length()
      match line[value_start:].find("\"") {
        Some(end) => line[value_start:value_start + end].to_owned()
        None => ""
      }
    }
    None => ""
  }
}

///|
pub impl ToJson for ExternalCoverage with fn to_json(self : ExternalCoverage) -> Json {
  let files = Array::new()
  for file in self.files {
    files.push(file.to_json())
  }
  Json::object({
    "format": Json::string(self.format),
    "total": Json::number(self.total.to_double()),
    "covered": Json::number(self.covered.to_double()),
    "percentage": Json::number(self.percentage.to_double()),
    "files": Json::array(files),
  })
}
