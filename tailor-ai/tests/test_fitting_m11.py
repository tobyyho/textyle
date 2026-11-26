"""Fail-closed tests for the experimental M11 fitter boundary."""

import pytest

from tailor_ai.garment3d.fitting import FitError, fit_static_long_sleeve


def test_unknown_profile_fails_before_asset_processing():
    with pytest.raises(FitError) as caught:
        fit_static_long_sleeve(b"", {}, b"", "unknown")
    assert caught.value.status == "unsupported_profile"


def test_unsupported_category_fails_without_template_substitution():
    with pytest.raises(FitError) as caught:
        fit_static_long_sleeve(b"", {"category": "trousers"}, b"", "male_average")
    assert caught.value.status == "unsupported_category"


def test_stale_canonical_identity_fails():
    sidecar = {"category": "long_sleeve_top", "versions": {"template": "long_sleeve_top_v1"},
               "glb_sha256": "0" * 64, "asset_fingerprint": "0" * 64}
    with pytest.raises(FitError) as caught:
        fit_static_long_sleeve(b"", sidecar, b"", "male_average")
    assert caught.value.status == "stale_canonical_asset"


def test_wrong_base_avatar_hash_fails():
    from tailor_ai.garment3d.fitting import CANONICAL_FINGERPRINT, digest

    sidecar = {"category": "long_sleeve_top", "versions": {"template": "long_sleeve_top_v1"},
               "glb_sha256": digest(b""), "asset_fingerprint": CANONICAL_FINGERPRINT}
    with pytest.raises(FitError) as caught:
        fit_static_long_sleeve(b"", sidecar, b"", "male_average")
    assert caught.value.status == "profile_version_mismatch"
