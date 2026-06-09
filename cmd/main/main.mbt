///|
fn main {
  let args = @env.args()
  let command_index = find_command(args)
  if command_index == -1 {
    print_help()
    return
  }
  let command = args[command_index]
  let path = if args.length() > command_index + 1 {
    args[command_index + 1]
  } else {
    "."
  }
  if command == "scan" {
    match @lib.analyze_project(path) {
      Ok(report) => println(@lib.render_report(report))
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "gate" {
    match @lib.analyze_project(path) {
      Ok(report) =>
        println(
          @lib.render_gate(@lib.evaluate_gate(report, @lib.default_policy())),
        )
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "mutants" {
    match @lib.analyze_project(path) {
      Ok(report) => println(@lib.render_mutants(@lib.mutation_plan(report)))
      Err(err) => println(@lib.format_error(err))
    }
  } else if command == "explain" {
    match @lib.analyze_project(path) {
      Ok(report) => println(@lib.summarize(report))
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
fn print_help() -> Unit {
  println("MoonSeal")
  println("usage:")
  println("  moon run --target js cmd/main -- scan <project>")
  println("  moon run --target js cmd/main -- gate <project>")
  println("  moon run --target js cmd/main -- mutants <project>")
  println("  moon run --target js cmd/main -- explain <project>")
}
