# ABOUTME: Tests claim YAML validation: required fields, enums, quote-in-page, extended diagnosis statuses.
from pathlib import Path
import yaml, validate_claim as vc

FX = Path(__file__).parent / "fixtures"

def _claim(): return yaml.safe_load((FX / "claim_ok.yaml").read_text())
def _page(): return (FX / "page_ok.txt").read_text()

def test_valid_claim_has_no_errors():
    assert vc.validate(_claim(), _page()) == []

def test_quote_not_in_page_is_error():
    c = _claim(); c["proposed_source"]["quote"] = "This sentence is absent."
    errs = vc.validate(c, _page())
    assert any("quote" in e for e in errs)

def test_new_diagnosis_status_allowed():
    c = _claim(); c["status"] = "cited-stale"
    assert vc.validate(c, _page()) == []

def test_unknown_status_rejected():
    c = _claim(); c["status"] = "bogus"
    assert any("status" in e for e in vc.validate(c, _page()))

def test_pending_audit_status_allowed():
    c = _claim(); c["status"] = "pending-audit"
    assert vc.validate(c, _page()) == []
