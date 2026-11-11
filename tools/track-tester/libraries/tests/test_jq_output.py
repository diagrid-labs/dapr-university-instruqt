import shutil
import subprocess

import pytest

from jq_output import output_should_be_pretty_json, pretty_json, split_pretty_json_with_status

DENIED = '{"errorCode":"ERR_PERMISSION_DENIED","message":"access denied by policy to get \\"orderdb-password\\" from \\"secretstore\\""}'
NESTED = '{"orderdb":{"password":"demo-nested-password","user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}'


def jq(text):
    return subprocess.run(["jq"], input=text, capture_output=True, text=True, check=True).stdout


needs_jq = pytest.mark.skipif(shutil.which("jq") is None, reason="jq is not installed")


@needs_jq
@pytest.mark.parametrize("compact", [DENIED, NESTED, '{"a":1}'])
def test_pretty_json_matches_jq(compact):
    assert pretty_json(compact) == jq(compact).rstrip("\n")


@needs_jq
def test_output_should_be_pretty_json_accepts_jq_output():
    output_should_be_pretty_json(jq(NESTED), NESTED)


def test_output_should_be_pretty_json_rejects_compact_or_other_values():
    with pytest.raises(AssertionError):
        output_should_be_pretty_json(NESTED, NESTED)
    with pytest.raises(AssertionError):
        output_should_be_pretty_json(pretty_json('{"a":2}'), '{"a":1}')


@needs_jq
@pytest.mark.parametrize("compact,status", [(DENIED, "403"), ('{"name":"x","value":"y"}', "200")])
def test_split_round_trips_the_curl_status_through_jq(compact, status):
    # What `curl -s -w ' %{http_code}\n' URL | jq` feeds jq: the body, a space, the status.
    result = split_pretty_json_with_status(jq(f"{compact} {status}\n"))
    assert result == {"body": compact, "status": status}


def test_split_rejects_a_body_that_is_not_pretty_printed():
    with pytest.raises(AssertionError, match="formatted"):
        split_pretty_json_with_status('{"a": 1}\n200')


def test_split_rejects_output_without_a_status_line():
    with pytest.raises(AssertionError, match="status line"):
        split_pretty_json_with_status("0")


def test_split_rejects_a_body_that_is_not_json():
    with pytest.raises(AssertionError, match="not JSON"):
        split_pretty_json_with_status("Bad Gateway\n502")
