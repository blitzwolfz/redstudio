// Local and plain-HTTP request inspector. TLS is deliberately not implied.
import "std/http" as http;
import "json" as json;

fun get(target) {
  if (!target.starts_with("http://")) {
    throw error("The inspector supports plain HTTP URLs only", target, "http");
  }
  const started = time();
  const response = http.get(target, {"timeout": 8, "follow": 2});
  let body = response.body;
  let parsed = nil;
  try { parsed = json.parse(body); }
  catch (e: "json") { parsed = nil; }
  return {"status": response.status, "headers": response.headers.entries,
          "body": body, "json": parsed, "duration": time() - started};
}
