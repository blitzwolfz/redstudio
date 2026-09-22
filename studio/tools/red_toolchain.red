// Red subprocess integration. Arguments are passed as an argv array.
fun executable() { return env("RED_EXECUTABLE", "red"); }

fun invoke(action, file, working_directory = nil) {
  let command = [executable()];
  if (action != "run") { command.push(action); }
  command.push(file);
  let result = run(command);
  return {"action": action, "command": command.join(" "),
          "code": result.get("code", -1), "out": result.get("out", ""),
          "err": result.get("err", ""), "status": "completed"};
}
