// Bounded concurrent command and HTTP work queue. Workers publish results;
// only the GUI owner reads and renders them.
import "../tools/red_toolchain.red" as red_toolchain;
import "../inspector/http.red" as http_inspector;
import "../project/search.red" as project_search;
import "json" as json;
import "std/path" as path;

fun worker(jobs, results) {
  for (;;) {
    const job = jobs.recv();
    if (job == nil) { return; }
    try {
      results.try_send({"event": "running", "id": job["id"]});
      let result = nil;
      if (job["action"] == "http-get" or job["action"] == "http-post") {
        let reply = nil;
        if (job["action"] == "http-post") {
          reply = http_inspector.post(job["file"], job["body"]);
        } else { reply = http_inspector.get(job["file"]); }
        let body = reply["body"];
        if (reply["json"] != nil) { body = json.stringify(reply["json"], 2); }
        let header_text = "";
        for (let name in reply["headers"].keys().sort()) {
          header_text += "${name}: ${reply["headers"][name]}\n";
        }
        let method = "GET";
        if (job["action"] == "http-post") { method = "POST"; }
        result = {"action": method, "command": job["file"], "code": reply["status"],
                  "out": "HTTP ${reply["status"]} (${reply["duration"]}s)\n" +
                         header_text + "\n" + body,
                  "err": "", "status": "completed"};
      } else if (job["action"] == "search") {
        const found = project_search.find(job["cwd"], job["file"]);
        let text = "${found.len()} matches for '${job["file"]}'\n";
        for (let match in found) {
          text += "${path.base(match["file"])}:${match["line"]}  ${match["text"]}\n";
        }
        result = {"action": "Search", "command": job["file"], "code": 0,
                  "out": text, "err": "", "status": "completed"};
      } else {
        result = red_toolchain.invoke(job["action"], job["file"], job["cwd"]);
      }
      result.set("id", job["id"]);
      result.set("started", job["started"]);
      result.set("duration", time() - job["started"]);
      if (job["action"] == "http-get" or job["action"] == "http-post") {
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
    this.tasks = [];
    this.workers = [];
    if (!headless) {
      for (let i in range(0, concurrency)) { this.workers.push(spawn worker(this.jobs, this.results)); }
    }
  }

  submit(action, file, cwd, body = "") {
    const id = this.next_id;
    this.next_id += 1;
    const job = {"id": id, "action": action, "file": file, "body": body,
                 "cwd": cwd, "started": time(), "status": "queued"};
    this.tasks.push(job);
    this.jobs.send(job);
    return id;
  }

  collect() {
    const fresh = [];
    for (;;) {
      const result = this.results.try_recv();
      if (result == nil) { break; }
      for (let task in this.tasks) {
        if (task["id"] != result["id"]) { continue; }
        if (result["event"] == "running") {
          task["status"] = "running";
          task["started"] = time();
          fresh.push(result);
        } else {
          task["status"] = result["status"];
          task["duration"] = result["duration"];
        }
        break;
      }
      if (result.get("event", "") == "running") { continue; }
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
