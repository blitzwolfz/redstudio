// JSON inspector helpers shared by files and HTTP responses.
import "json" as json;

fun inspect(source) {
  const value = json.parse(source);
  return {"value": value, "formatted": json.stringify(value, 2),
          "kind": type(value)};
}

fun summary(value) {
  if (type(value) == "map") {
    let rows = [];
    for (let key in value.keys().sort()) {
      rows.push({"key": key, "type": type(value[key]), "value": str(value[key])});
    }
    return rows;
  }
  if (type(value) == "array") {
    let rows = [];
    for (let i in range(0, value.len())) {
      rows.push({"key": "[${i}]", "type": type(value[i]), "value": str(value[i])});
    }
    return rows;
  }
  return [{"key": "value", "type": type(value), "value": str(value)}];
}
