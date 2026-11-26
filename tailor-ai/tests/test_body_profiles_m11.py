"""M11 synthetic profile geometry identity and non-destructive deformation checks."""

import numpy as np
import pytest

from tailor_ai.garment3d.body_profiles import (
    GEOMETRY_VERSION,
    PROFILES,
    deform_world_vertices,
    profile_fingerprint,
)


def test_all_six_frozen_profiles_and_bounded_parameters():
    assert GEOMETRY_VERSION == "body-profile-geometry-v1"
    assert set(PROFILES) == {
        "male_slim", "male_average", "male_athletic",
        "female_slim", "female_average", "female_curvy",
    }
    assert all(abs(v) <= .15 for p in PROFILES.values() for v in p.parameters().values())


def test_average_identity_and_local_variants_deterministic():
    vertices = np.array([[x, y, z] for x in (-.28, -.20, 0, .20, .28)
                         for y in (.50, 1.00, 1.30, 1.50, 1.80)
                         for z in (-.1, .1)], dtype=float)
    for family in ("male", "female"):
        average = deform_world_vertices(vertices, f"{family}_average")
        assert np.array_equal(average, vertices)
        ids = ("male_slim", "male_athletic") if family == "male" else ("female_slim", "female_curvy")
        results = [deform_world_vertices(vertices, name) for name in ids]
        assert all(np.array_equal(a, deform_world_vertices(vertices, name)) for a, name in zip(results, ids))
        assert all(not np.array_equal(a, average) for a in results)
        assert not np.array_equal(results[0], results[1])
        for result in results:
            assert np.isfinite(result).all()
            assert np.array_equal(result[:, 1], vertices[:, 1])
            # Face/feet are outside smooth regional deformation support.
            assert np.array_equal(result[vertices[:, 1] == .50], vertices[vertices[:, 1] == .50])
            assert np.array_equal(result[vertices[:, 1] == 1.80], vertices[vertices[:, 1] == 1.80])


def test_profile_fingerprint_binds_base_and_identity():
    first = profile_fingerprint("male_slim", "a" * 64)
    assert len(first) == 64
    assert first == profile_fingerprint("male_slim", "a" * 64)
    assert first != profile_fingerprint("male_average", "a" * 64)
    assert first != profile_fingerprint("male_slim", "b" * 64)
    with pytest.raises(KeyError):
        profile_fingerprint("unknown", "a" * 64)
