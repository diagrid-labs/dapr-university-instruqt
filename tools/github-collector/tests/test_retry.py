from types import SimpleNamespace

import pytest
from github import GithubException, RateLimitExceededException

import collect_github_data as c
from collect_github_data import call_with_retry, _default_reset_seconds


def test_returns_value_without_error():
    assert call_with_retry(lambda: 42, sleep=lambda s: None) == 42


def test_secondary_limit_backoff_then_success():
    calls = {"n": 0}

    def fn():
        calls["n"] += 1
        if calls["n"] < 3:
            raise GithubException(403, {"message": "secondary rate limit"}, None)
        return "ok"

    slept = []
    result = call_with_retry(fn, max_retries=5, sleep=slept.append)
    assert result == "ok"
    assert calls["n"] == 3
    assert slept == [1, 2]  # 2**0, 2**1


def test_secondary_limit_exhausts_and_raises():
    def fn():
        raise GithubException(403, {"message": "secondary"}, None)

    with pytest.raises(GithubException):
        call_with_retry(fn, max_retries=2, sleep=lambda s: None)


def test_non_403_github_exception_propagates_immediately():
    def fn():
        raise GithubException(500, {"message": "server"}, None)

    with pytest.raises(GithubException):
        call_with_retry(fn, max_retries=5, sleep=lambda s: None)


def test_primary_rate_limit_sleeps_until_reset_then_succeeds():
    calls = {"n": 0}

    def fn():
        calls["n"] += 1
        if calls["n"] == 1:
            raise RateLimitExceededException(403, {"message": "rate"}, {})
        return "done"

    slept = []
    result = call_with_retry(fn, sleep=slept.append, reset_seconds=lambda e: 5)
    assert result == "done"
    assert slept == [5]


def test_default_reset_seconds_future_header(monkeypatch):
    monkeypatch.setattr(c.time, "time", lambda: 1000)
    exc = SimpleNamespace(headers={"x-ratelimit-reset": "1050"})
    assert _default_reset_seconds(exc) == 50


def test_default_reset_seconds_past_header_clamped_to_one(monkeypatch):
    monkeypatch.setattr(c.time, "time", lambda: 1000)
    exc = SimpleNamespace(headers={"x-ratelimit-reset": "900"})  # already past
    assert _default_reset_seconds(exc) == 1


def test_default_reset_seconds_missing_header_falls_back():
    exc = SimpleNamespace(headers={})
    assert _default_reset_seconds(exc) == 60


def test_default_reset_seconds_garbage_header_falls_back():
    exc = SimpleNamespace(headers={"x-ratelimit-reset": "not-a-number"})
    assert _default_reset_seconds(exc) == 60
