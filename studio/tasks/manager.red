// Bounded concurrent command and HTTP work queue. Workers publish results;
// only the GUI owner reads and renders them.
import "../tools/red_toolchain.red" as red_toolchain;
import "../inspector/http.red" as http_inspector;
import "json" as json;

fun worker(jobs, results) {
  for (;;) {
    const job = jobs.recv();
    if (job == nil) { return; }
    try {
      let result = nil;
      if (job["action"] == "http-get") {
        const reply = http_inspector.get(job["file"]);
        let body = reply["body"];
        if (reply["json"] != nil) { body = json.stringify(reply["json"], 2); }
        let header_text = "";
        for (let name in reply["headers"].keys().sort()) {
          header_text += "${name}: ${reply["headers"][name]}\n";
        }
        result = {"action": "GET", "command": job["file"], "code": reply["status"],
                  "out": "HTTP ${reply["status"]} (${reply["duration"]}s)\n" +
                         header_text + "\n" + body,
                  "err": "", "status": "completed"};
      } else {
        result = red_toolchain.invoke(job["action"], job["file"], job["cwd"]);
      }
      result.set("id", job["id"]);
      result.set("started", job["started"]);
      result.set("duration", time() - job["started"]);
      if (job["action"] == "http-get") {
        if (result["code"] < 200 or result["code"] >= 300) {
          result["status"] = "failed";
        }
      } else if (result["code"] != 0) { result["status"] = "failed"; }
      results.send(result);
    } catch (e) {
      results.send({"id": job["id"], "action": job["action"],
                    "status": "failed", "code": -1,
                    "out": "", "err": e.message,
                    "started": job["started"],
                    "duration": time() - job["started"]});
    }
  }
}

class Manager {
  init(concurrency = 2, headless = false) {
    this.jobs = chan(64);
    this.results = chan(64);
    this.next_id = 1;
    this.history = [];
    this.workers = [];
    if (!headless) {
      for (let i in range(0, concurrency)) { this.workers.push(spawn worker(this.jobs, this.results)); }
    }
  }

  submit(action, file, cwd) {
    const id = this.next_id;
    this.next_id += 1;
    this.jobs.send({"id": id, "action": action, "file": file,
                    "cwd": cwd, "started": time(), "status": "queued"});
    return id;
  }

  collect() {
    const fresh = [];
    for (;;) {
      const result = this.results.try_recv();
      if (result == nil) { break; }
      this.history.push(result);
      fresh.push(result);
    }
    return fresh;
  }

  shutdown() {
    this.jobs.close();
    for (let task in this.workers) {
      try { task.join(); } catch (e) { }
    }
  }
}
