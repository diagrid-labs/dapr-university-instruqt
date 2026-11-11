"""Robot keywords for assignment commands that pipe curl into jq.

The dapr-secrets assignments show HTTP responses through jq (`curl -s URL | jq`), and the calls
that report the HTTP status as well use `curl -s -w ' %{http_code}\\n' URL | jq`: jq reads the body
and then the status as a second JSON value, so it prints the formatted body with the status on the
last line. These keywords check that output against the compact JSON the suites keep as their
expected values, and check that it is exactly jq's default formatting (2-space indent,
`"key": value`), which is also what the assignments' expected-output blocks show.
"""
import json

ROBOT_LIBRARY_SCOPE = "GLOBAL"


def pretty_json(compact):
    """Return compact JSON as jq prints it by default."""
    return json.dumps(json.loads(compact), indent=2, ensure_ascii=False)


def _compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def output_should_be_pretty_json(output, compact):
    """Fail unless `output` is exactly the jq formatting of the JSON in `compact`."""
    expected = pretty_json(compact)
    actual = output.strip()
    if actual != expected:
        raise AssertionError(f"jq output differs.\nExpected:\n{expected}\nActual:\n{actual}")


def split_pretty_json_with_status(output):
    """Split the output of `curl -s -w ' %{http_code}\\n' URL | jq` into body and status.

    Returns a dictionary with `body` (the JSON re-encoded compact, in the order jq printed it) and
    `status` (the last line, as text). Fails when the body is not jq's default formatting.
    """
    lines = output.strip().split("\n")
    if len(lines) < 2:
        raise AssertionError(f"Expected a JSON body and a status line, got:\n{output}")
    status = lines[-1].strip()
    body_text = "\n".join(lines[:-1])
    try:
        value = json.loads(body_text)
    except ValueError as err:
        raise AssertionError(f"The body is not JSON ({err}):\n{body_text}") from None
    if body_text != json.dumps(value, indent=2, ensure_ascii=False):
        raise AssertionError(f"The body is not formatted the way jq prints it:\n{body_text}")
    return {"body": _compact(value), "status": status}
