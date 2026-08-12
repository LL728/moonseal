///|
fn main {
  let args = @env.args()
  let command_index = find_command(args)
  if command_index == -1 {
    print_help()
    return
  }
  let command = args[command_index]
  let path = find_path(args, command_index)
  let (json_flag, mutate_flag, coverage_flag, baseline_path, output_path) = parse_flags(
    args,
  )

  if command == "scan" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let mut rep = report
        if mutate_flag {
          let (tested, killed, score, survived) = @lib.run_mutation_testing(
            path,
            rep.mutation_candidates,
          )
          rep = {
            ..rep,
            mutants_tested: tested,
            mutants_killed: killed,
            mutation_score: score,
            survived_mutants: survived,
          }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          rep = {
            ..rep,
            coverage_total_percentage: total_cov,
            coverage_files: files_cov,
          }
        }
        if json_flag {
          println(rep.to_json().stringify(indent=2))
        } else {
          println(@lib.render_report(rep))
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "gate" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let mut rep = report
        if mutate_flag {
          let (tested, killed, score, survived) = @lib.run_mutation_testing(
            path,
            rep.mutation_candidates,
          )
          rep = {
            ..rep,
            mutants_tested: tested,
            mutants_killed: killed,
            mutation_score: score,
            survived_mutants: survived,
          }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          rep = {
            ..rep,
            coverage_total_percentage: total_cov,
            coverage_files: files_cov,
          }
        }
        let policy = @lib.load_policy(path)
        let gate_res = @lib.evaluate_gate(rep, policy)
        if json_flag {
          println(gate_res.to_json().stringify(indent=2))
        } else {
          println(@lib.render_gate(gate_res))
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "mutants" {
    match @lib.analyze_project(path) {
      Ok(report) =>
        if json_flag {
          let arr = Array::new()
          for mc in @lib.mutation_plan(report) {
            arr.push(mc.to_json())
          }
          println(Json::array(arr).stringify(indent=2))
        } else {
          println(@lib.render_mutants(@lib.mutation_plan(report)))
        }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "explain" {
    match @lib.analyze_project(path) {
      Ok(report) =>
        if json_flag {
          println(Json::string(@lib.summarize(report)).stringify(indent=2))
        } else {
          println(@lib.summarize(report))
        }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "snapshot" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let snapshot = @lib.make_snapshot(report)
        if output_path.length() > 0 {
          match @lib.write_snapshot(output_path, snapshot) {
            Ok(_) => println("MoonSeal baseline written: " + output_path)
            Err(message) => println("MoonSeal baseline error: " + message)
          }
        } else if json_flag {
          println(snapshot.to_json().stringify(indent=2))
        } else {
          println("MoonSeal baseline preview")
          println(snapshot.to_json().stringify(indent=2))
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "compare" {
    if baseline_path.length() == 0 {
      println("MoonSeal baseline error: use --baseline <file>")
      return
    }
    match @lib.analyze_project(path) {
      Ok(report) => {
        let mut current = report
        if mutate_flag {
          let (tested, killed, score, survived) = @lib.run_mutation_testing(
            path,
            current.mutation_candidates,
          )
          current = {
            ..current,
            mutants_tested: tested,
            mutants_killed: killed,
            mutation_score: score,
            survived_mutants: survived,
          }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          current = {
            ..current,
            coverage_total_percentage: total_cov,
            coverage_files: files_cov,
          }
        }
        match @lib.read_snapshot(baseline_path) {
          Ok(baseline) => {
            let result = @lib.compare_snapshot(
              @lib.make_snapshot(current),
              baseline,
            )
            if json_flag {
              println(result.to_json().stringify(indent=2))
            } else {
              println(@lib.render_comparison(result))
            }
          }
          Err(message) => println("MoonSeal baseline error: " + message)
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "recommend" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let items = @lib.recommendations(report)
        if json_flag {
          let values = Array::new()
          for item in items {
            values.push(item.to_json())
          }
          println(Json::array(values).stringify(indent=2))
        } else {
          println(@lib.render_recommendations(items))
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "sarif" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let mut current = report
        if mutate_flag {
          let (tested, killed, score, survived) = @lib.run_mutation_testing(
            path,
            current.mutation_candidates,
          )
          current = {
            ..current,
            mutants_tested: tested,
            mutants_killed: killed,
            mutation_score: score,
            survived_mutants: survived,
          }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          current = {
            ..current,
            coverage_total_percentage: total_cov,
            coverage_files: files_cov,
          }
        }
        let gate = @lib.evaluate_gate(current, @lib.load_policy(path))
        let sarif = @lib.render_sarif(current, gate)
        if output_path.length() > 0 {
          match @lib.write_text(output_path, sarif + "\n") {
            Ok(_) => println("MoonSeal SARIF written: " + output_path)
            Err(message) => println("MoonSeal SARIF error: " + message)
          }
        } else {
          println(sarif)
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else {
    print_help()
  }
}

///|
fn find_command(args : Array[String]) -> Int {
  for i in 0..<args.length() {
    if args[i] == "scan" ||
      args[i] == "gate" ||
      args[i] == "mutants" ||
      args[i] == "explain" ||
      args[i] == "snapshot" ||
      args[i] == "compare" ||
      args[i] == "recommend" ||
      args[i] == "sarif" {
      return i
    }
  }
  -1
}

///|
fn parse_flags(args : Array[String]) -> (Bool, Bool, Bool, String, String) {
  let mut json = false
  let mut mutate = false
  let mut coverage = false
  let mut baseline = ""
  let mut output = ""
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "--json" || arg == "-j" {
      json = true
    } else if arg == "--mutate" || arg == "-m" {
      mutate = true
    } else if arg == "--coverage" || arg == "-c" {
      coverage = true
    }
    if arg == "--baseline" && index + 1 < args.length() {
      index += 1
      baseline = args[index]
    } else if (arg == "--output" || arg == "-o") && index + 1 < args.length() {
      index += 1
      output = args[index]
    }
    index += 1
  }
  (json, mutate, coverage, baseline, output)
}

///|
fn find_path(args : Array[String], cmd_idx : Int) -> String {
  let mut i = cmd_idx + 1
  while i < args.length() {
    if !args[i].has_prefix("-") {
      return args[i]
    }
    i += 1
  }
  "."
}

///|
fn print_help() -> Unit {
  println("MoonSeal")
  println("usage:")
  println(
    "  moon run --target js cmd/main -- scan <project> [--json] [--mutate] [--coverage]",
  )
  println(
    "  moon run --target js cmd/main -- gate <project> [--json] [--mutate] [--coverage]",
  )
  println("  moon run --target js cmd/main -- mutants <project> [--json]")
  println("  moon run --target js cmd/main -- explain <project> [--json]")
  println(
    "  moon run --target js cmd/main -- snapshot <project> [--output <file>] [--json]",
  )
  println(
    "  moon run --target js cmd/main -- compare <project> --baseline <file> [--mutate] [--coverage] [--json]",
  )
  println("  moon run --target js cmd/main -- recommend <project> [--json]")
  println(
    "  moon run --target js cmd/main -- sarif <project> [--output <file>] [--mutate] [--coverage]",
  )
}
