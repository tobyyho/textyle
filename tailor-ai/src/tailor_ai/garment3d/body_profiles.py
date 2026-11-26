"""Frozen synthetic avatar geometry presets for M11 static-pose fitting.

All coordinates here are Textyle avatar world space: +Y up, +Z forward.
These are not anthropometric population measurements.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass

import numpy as np

GEOMETRY_VERSION = "body-profile-geometry-v1"
WORLD_VERSION = "textyle-avatar-world-y-up-z-front-v1"


@dataclass(frozen=True)
class ProfileDefinition:
    profile_id: str
    base_family: str
    upper_torso_x: float = 0.0
    lower_torso_x: float = 0.0
    torso_z: float = 0.0
    shoulder_x: float = 0.0
    upper_arm: float = 0.0
    forearm: float = 0.0

    def parameters(self) -> dict[str, float]:
        return {name: getattr(self, name) for name in (
            "upper_torso_x", "lower_torso_x", "torso_z", "shoulder_x",
            "upper_arm", "forearm",
        )}


PROFILES = {
    p.profile_id: p for p in (
        ProfileDefinition("male_slim", "male", -.08, -.07, -.07, -.05, -.08, -.06),
        ProfileDefinition("male_average", "male"),
        ProfileDefinition("male_athletic", "male", .10, .02, .05, .10, .08, .04),
        ProfileDefinition("female_slim", "female", -.06, -.08, -.07, -.04, -.07, -.06),
        ProfileDefinition("female_average", "female"),
        ProfileDefinition("female_curvy", "female", .04, .11, .12, .02, .03, .02),
    )
}


def _smoothstep(low: float, high: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def profile_fingerprint(profile_id: str, base_sha256: str) -> str:
    definition = PROFILES[profile_id]
    identity = {
        "base_sha256": base_sha256.lower(),
        "profile_id": profile_id,
        "geometry_version": GEOMETRY_VERSION,
        "world_version": WORLD_VERSION,
        "parameters": definition.parameters(),
    }
    return hashlib.sha256(json.dumps(identity, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def deform_world_vertices(vertices: np.ndarray, profile_id: str) -> np.ndarray:
    """Smooth X/Z-only regional deformation; average returns exact base copy."""
    definition = PROFILES[profile_id]
    original = np.asarray(vertices, dtype=np.float64)
    if original.ndim != 2 or original.shape[1] != 3 or not np.isfinite(original).all():
        raise ValueError("Avatar vertices must be finite Nx3")
    if not any(definition.parameters().values()):
        return original.copy()
    x, y, z = original.T
    torso_support = _smoothstep(.78, .97, y) * (1 - _smoothstep(1.57, 1.70, y))
    arm_support = _smoothstep(.88, 1.04, y) * (1 - _smoothstep(1.58, 1.70, y))
    arm_region = _smoothstep(.17, .27, np.abs(x))
    torso_region = 1 - arm_region
    upper = _smoothstep(1.15, 1.39, y)
    shoulder = np.exp(-((y - 1.48) / .12) ** 2)
    torso_x_delta = (definition.lower_torso_x * (1 - upper)
                     + definition.upper_torso_x * upper
                     + definition.shoulder_x * .45 * shoulder)
    arm_upper = _smoothstep(1.10, 1.37, y)
    arm_delta = definition.forearm * (1 - arm_upper) + definition.upper_arm * arm_upper
    x_torso = x * (1 + torso_support * torso_x_delta)
    arm_center = np.sign(x) * .27
    x_arm = (arm_center * (1 + definition.shoulder_x * shoulder * arm_support)
             + (x - arm_center) * (1 + arm_delta * arm_support))
    new_x = x_torso * torso_region + x_arm * arm_region
    torso_z = .018 + (z - .018) * (1 + definition.torso_z * torso_support)
    arm_z = z * (1 + arm_delta * arm_support)
    new_z = torso_z * torso_region + arm_z * arm_region
    result = np.column_stack((new_x, y, new_z))
    if not np.isfinite(result).all():
        raise ValueError("Profile deformation produced non-finite geometry")
    return result
