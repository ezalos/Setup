# ABOUTME: Tests Tavily key resolution and request-payload construction without hitting the network.
import json
import tavily_cli as tv

def test_key_from_env(monkeypatch):
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-env")
    assert tv.resolve_key() == "tvly-env"

def test_key_from_file(monkeypatch, tmp_path):
    monkeypatch.delenv("TAVILY_API_KEY", raising=False)
    f = tmp_path / "tavily_api_key"
    f.write_text("tvly-file\n")
    assert tv.resolve_key(key_file=f) == "tvly-file"

def test_missing_key_raises(monkeypatch, tmp_path):
    monkeypatch.delenv("TAVILY_API_KEY", raising=False)
    import pytest
    with pytest.raises(RuntimeError):
        tv.resolve_key(key_file=tmp_path / "nope")

def test_search_payload():
    body = tv.build_search_payload("ai market 2026", max_results=3,
                                   include_domains=["gartner.com"], days=180)
    assert body["query"] == "ai market 2026"
    assert body["max_results"] == 3
    assert body["include_domains"] == ["gartner.com"]
    assert body["days"] == 180

def test_extract_payload():
    body = tv.build_extract_payload("https://x.com/a")
    assert body["urls"] == ["https://x.com/a"]
    assert body["extract_depth"] == "advanced"
    assert body["format"] == "markdown"
