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
  let (json_flag, mutate_flag, coverage_flag) = parse_flags(args)
  
  if command == "scan" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        let mut rep = report
        if mutate_flag {
          let (tested, killed, score, survived) = @lib.run_mutation_testing(path, rep.mutation_candidates)
          rep = { ..rep, mutants_tested: tested, mutants_killed: killed, mutation_score: score, survived_mutants: survived }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          rep = { ..rep, coverage_total_percentage: total_cov, coverage_files: files_cov }
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
          let (tested, killed, score, survived) = @lib.run_mutation_testing(path, rep.mutation_candidates)
          rep = { ..rep, mutants_tested: tested, mutants_killed: killed, mutation_score: score, survived_mutants: survived }
        }
        if coverage_flag {
          let (total_cov, files_cov) = @lib.run_coverage_analysis(path)
          rep = { ..rep, coverage_total_percentage: total_cov, coverage_files: files_cov }
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
      Ok(report) => {
        if json_flag {
          let arr = Array::new()
          for mc in @lib.mutation_plan(report) {
            arr.push(mc.to_json())
          }
          println(Json::array(arr).stringify(indent=2))
        } else {
          println(@lib.render_mutants(@lib.mutation_plan(report)))
        }
      }
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "explain" {
    match @lib.analyze_project(path) {
      Ok(report) => {
        if json_flag {
          println(Json::string(@lib.summarize(report)).stringify(indent=2))
        } else {
          println(@lib.summarize(report))
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
      args[i] == "explain" {
      return i
    }
  }
  -1
}

///|
fn parse_flags(args : Array[String]) -> (Bool, Bool, Bool) {
  let mut json = false
  let mut mutate = false
  let mut coverage = false
  for arg in args {
    if arg == "--json" || arg == "-j" {
      json = true
    } else if arg == "--mutate" || arg == "-m" {
      mutate = true
    } else if arg == "--coverage" || arg == "-c" {
      coverage = true
    }
  }
  (json, mutate, coverage)
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
  println("  moon run --target js cmd/main -- scan <project> [--json] [--mutate] [--coverage]")
  println("  moon run --target js cmd/main -- gate <project> [--json] [--mutate] [--coverage]")
  println("  moon run --target js cmd/main -- mutants <project> [--json]")
  println("  moon run --target js cmd/main -- explain <project> [--json]")
}
