///|
/// Historical quality snapshots are append-only release evidence.
pub(all) struct QualityHistory {
  schema_version : Int
  snapshots : Array[QualitySnapshot]
} derive(Eq)

///|
/// Directional changes between the first and latest recorded snapshots.
pub(all) struct TrendReport {
  sample_count : Int
  first_version : String
  latest_version : String
  source_file_delta : Int
  test_file_delta : Int
  mutation_score_delta : Int
  coverage_delta : Int
  warning_delta : Int
  direction : String
} derive(Eq)

///|
/// Create an empty, versioned history document from an optional seed list.
pub fn make_history(snapshots : Array[QualitySnapshot]) -> QualityHistory {
  let copied : Array[QualitySnapshot] = []
  for snapshot in snapshots {
    copied.push(snapshot)
  }
  { schema_version: 1, snapshots: copied }
}

///|
/// Append a snapshot without mutating the caller's history value.
pub fn append_history(
  history : QualityHistory,
  snapshot : QualitySnapshot,
) -> QualityHistory {
  let snapshots : Array[QualitySnapshot] = []
  for item in history.snapshots {
    snapshots.push(item)
  }
  snapshots.push(snapshot)
  { schema_version: history.schema_version, snapshots }
}

///|
/// Summarize changes from the first sample to the latest sample.
pub fn summarize_history(history : QualityHistory) -> TrendReport {
  if history.snapshots.length() == 0 {
    return {
      sample_count: 0,
      first_version: "",
      latest_version: "",
      source_file_delta: 0,
      test_file_delta: 0,
      mutation_score_delta: 0,
      coverage_delta: 0,
      warning_delta: 0,
      direction: "empty",
    }
  }
  let first = history.snapshots[0]
  let latest = history.snapshots[history.snapshots.length() - 1]
  let source_delta = latest.source_files - first.source_files
  let test_delta = latest.test_files - first.test_files
  let mutation_delta = latest.mutation_score - first.mutation_score
  let coverage_delta = latest.coverage_total_percentage -
    first.coverage_total_percentage
  let warning_delta = latest.warning_count - first.warning_count
  {
    sample_count: history.snapshots.length(),
    first_version: first.version,
    latest_version: latest.version,
    source_file_delta: source_delta,
    test_file_delta: test_delta,
    mutation_score_delta: mutation_delta,
    coverage_delta,
    warning_delta,
    direction: trend_direction(
      source_delta, test_delta, mutation_delta, coverage_delta, warning_delta,
    ),
  }
}

///|
/// Render a concise trend suitable for CI logs and release notes.
pub fn render_history(report : TrendReport) -> String {
  let out = StringBuilder()
  out.write_string("MoonSeal quality history: " + report.direction + "\n")
  out.write_string("samples: " + report.sample_count.to_string() + "\n")
  out.write_string(
    "versions: " + report.first_version + " -> " + report.latest_version + "\n",
  )
  out.write_string("source-files: " + signed(report.source_file_delta) + "\n")
  out.write_string("test-files: " + signed(report.test_file_delta) + "\n")
  out.write_string(
    "mutation-score: " + signed(report.mutation_score_delta) + "\n",
  )
  out.write_string("coverage: " + signed(report.coverage_delta) + "\n")
  out.write_string("warnings: " + signed(report.warning_delta) + "\n")
  out.to_string()
}

///|
/// Parse an append-only history document.
pub fn parse_history(input : String) -> Result[QualityHistory, String] {
  try {
    match @json.parse(input) {
      Object(map) => {
        let schema_version = match required_int(map, "schema_version") {
          Ok(value) => value
          Err(message) =>
            return Err(message.replace(old="baseline", new="history"))
        }
        if schema_version != 1 {
          return Err(
            "unsupported history schema_version: " + schema_version.to_string(),
          )
        }
        let snapshots = match map.get("snapshots") {
          Some(Array(items)) => {
            let result : Array[QualitySnapshot] = []
            for item in items {
              match item {
                Object(snapshot_map) =>
                  match parse_snapshot_object(snapshot_map) {
                    Ok(snapshot) => result.push(snapshot)
                    Err(message) => return Err(message)
                  }
                _ => return Err("history snapshots must contain objects")
              }
            }
            result
          }
          _ => return Err("history field is missing or not an array: snapshots")
        }
        Ok({ schema_version, snapshots })
      }
      _ => Err("history must be a JSON object")
    }
  } catch {
    _ => Err("history is not valid JSON")
  }
}

///|
/// Read a history file created by `write_history`.
pub fn read_history(path : String) -> Result[QualityHistory, String] {
  if !fs_exists(path) {
    return Err("history file not found: " + path)
  }
  parse_history(fs_read(path))
}

///|
/// Write a stable, human-readable history archive.
pub fn write_history(
  path : String,
  history : QualityHistory,
) -> Result[Unit, String] {
  write_text(path, history.to_json().stringify(indent=2) + "\n")
}

///|
fn trend_direction(
  source_delta : Int,
  test_delta : Int,
  mutation_delta : Int,
  coverage_delta : Int,
  warning_delta : Int,
) -> String {
  if source_delta == 0 &&
    test_delta == 0 &&
    mutation_delta == 0 &&
    coverage_delta == 0 &&
    warning_delta == 0 {
    return "steady"
  }
  let quality_positive = test_delta > 0 ||
    mutation_delta > 0 ||
    coverage_delta > 0
  let quality_negative = test_delta < 0 ||
    mutation_delta < 0 ||
    coverage_delta < 0
  if quality_positive && (quality_negative || warning_delta > 0) {
    "mixed"
  } else if quality_negative || warning_delta > 0 {
    "declining"
  } else {
    "improving"
  }
}

///|
fn signed(value : Int) -> String {
  if value > 0 {
    "+" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub impl ToJson for QualityHistory with fn to_json(self : QualityHistory) -> Json {
  let snapshots = Array::new()
  for snapshot in self.snapshots {
    snapshots.push(snapshot.to_json())
  }
  Json::object({
    "schema_version": Json::number(self.schema_version.to_double()),
    "snapshots": Json::array(snapshots),
  })
}

///|
pub impl ToJson for TrendReport with fn to_json(self : TrendReport) -> Json {
  Json::object({
    "sample_count": Json::number(self.sample_count.to_double()),
    "first_version": Json::string(self.first_version),
    "latest_version": Json::string(self.latest_version),
    "source_file_delta": Json::number(self.source_file_delta.to_double()),
    "test_file_delta": Json::number(self.test_file_delta.to_double()),
    "mutation_score_delta": Json::number(self.mutation_score_delta.to_double()),
    "coverage_delta": Json::number(self.coverage_delta.to_double()),
    "warning_delta": Json::number(self.warning_delta.to_double()),
    "direction": Json::string(self.direction),
  })
}
