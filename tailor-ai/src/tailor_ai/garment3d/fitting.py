"""Experimental M11 static-pose long-sleeve fit, gated by profile validation.

This is deterministic geometric fitting, not cloth physics or body measurement.
"""

from __future__ import annotations

import hashlib
import io
import json
from collections import defaultdict
from dataclasses import dataclass
from time import perf_counter

import numpy as np
import trimesh
from scipy.interpolate import RegularGridInterpolator
from scipy.ndimage import gaussian_filter, maximum_filter, minimum_filter
from scipy.spatial import cKDTree

from tailor_ai.garment3d.body_profiles import (
    GEOMETRY_VERSION,
    PROFILES,
    deform_world_vertices,
    profile_fingerprint,
)

FITTER_VERSION = "static-semantic-cage-fit-v1"
CLEARANCE_VERSION = "profile-envelope-0p01-v1"
BASE_SHA256 = {
    "male": "81cad65007332e8f12473e141f28164f2ee7ee6e50589e220e84fa98309379fc",
    "female": "f3ae1679265d785f6255e39ccdbe664135bcdc5aa78497ec31ed9f195c8131dc",
}
CANONICAL_FINGERPRINT = "ef72a0f64828ff48db77aa077c1e675559c819695efe47fb4793802c2f70d0b8"


class FitError(ValueError):
    def __init__(self, status: str, message: str):
        super().__init__(message)
        self.status = status


@dataclass(frozen=True)
class FitResult:
    glb: bytes
    sidecar: dict


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _smoothstep(lo: float, hi: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def _cage(body: np.ndarray) -> tuple[RegularGridInterpolator, RegularGridInterpolator]:
    xs = np.linspace(-.36, .36, 29)
    ys = np.linspace(.78, 1.70, 39)
    tree = cKDTree(body[:, :2])
    front = np.empty((len(xs), len(ys)))
    back = np.empty_like(front)
    for i, xx in enumerate(xs):
        for j, yy in enumerate(ys):
            _, nearest = tree.query([xx, yy], k=50)
            z = body[nearest, 2]
            front[i, j], back[i, j] = z.max(), z.min()
    front = maximum_filter(gaussian_filter(front, 1), size=3)
    back = minimum_filter(gaussian_filter(back, 1), size=3)
    return (RegularGridInterpolator((xs, ys), front, bounds_error=False, fill_value=None),
            RegularGridInterpolator((xs, ys), back, bounds_error=False, fill_value=None))


def _boundary_sizes(scene: trimesh.Scene) -> list[int]:
    joined = scene.to_geometry()
    rounded, remap = np.unique(np.round(joined.vertices, 6), axis=0, return_inverse=True)
    faces = remap[joined.faces]
    edges = np.sort(np.vstack((faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]])), axis=1)
    unique, counts = np.unique(edges, axis=0, return_counts=True)
    if (counts > 2).any() or not np.isfinite(rounded).all():
        raise FitError("invalid_topology", "non-manifold or non-finite fitted shell")
    boundary = unique[counts == 1]
    adjacency: dict[int, list[int]] = defaultdict(list)
    for a, b in boundary:
        adjacency[int(a)].append(int(b))
        adjacency[int(b)].append(int(a))
    if any(len(neighbors) != 2 for neighbors in adjacency.values()):
        raise FitError("invalid_topology", "open tear in fitted shell")
    remaining = {tuple(map(int, edge)) for edge in boundary}
    sizes = []
    while remaining:
        start = min(remaining)[0]
        previous, current, size = -1, start, 0
        while True:
            size += 1
            choices = adjacency[current]
            nxt = choices[0] if choices[0] != previous else choices[1]
            remaining.discard(tuple(sorted((current, nxt))))
            previous, current = current, nxt
            if current == start:
                break
            if size > len(boundary):
                raise FitError("invalid_topology", "fitted boundary did not close")
        sizes.append(size)
    return sorted(sizes)


def fit_static_long_sleeve(canonical_glb: bytes, canonical_sidecar: dict,
                           base_avatar_glb: bytes, profile_id: str) -> FitResult:
    started = perf_counter()
    if profile_id not in PROFILES:
        raise FitError("unsupported_profile", "unknown canonical body profile")
    profile = PROFILES[profile_id]
    if (canonical_sidecar.get("category") != "long_sleeve_top" or
        canonical_sidecar.get("versions", {}).get("template") != "long_sleeve_top_v1"):
        raise FitError("unsupported_category", "only long_sleeve_top_v1 can be fitted")
    if (canonical_sidecar.get("glb_sha256") != digest(canonical_glb) or
        canonical_sidecar.get("asset_fingerprint") != CANONICAL_FINGERPRINT):
        raise FitError("stale_canonical_asset", "canonical garment identity mismatch")
    if digest(base_avatar_glb) != BASE_SHA256[profile.base_family]:
        raise FitError("profile_version_mismatch", "unrecognized base avatar hash")
    if set(canonical_sidecar.get("boundary_loops", {})) != {"neck", "left_cuff", "right_cuff", "hem"}:
        raise FitError("stale_canonical_asset", "canonical opening contract missing")
    try:
        source = trimesh.load(io.BytesIO(canonical_glb), file_type="glb", force="scene")
        base = trimesh.load(io.BytesIO(base_avatar_glb), file_type="glb", force="scene").to_geometry()
    except Exception as exc:
        raise FitError("invalid_glb", "canonical garment or base avatar GLB is not parseable") from exc
    if set(source.geometry) != {"garment_front", "garment_back", "garment_seams"}:
        raise FitError("stale_canonical_asset", "canonical primitive names differ")
    baseline_loops = _boundary_sizes(source)
    if baseline_loops != sorted(v["vertices"] for v in canonical_sidecar["boundary_loops"].values()):
        raise FitError("stale_canonical_asset", "canonical GLB opening topology differs")
    mark = perf_counter()
    body = deform_world_vertices(base.vertices, profile_id)
    body_time = (perf_counter() - mark) * 1000
    height_ratio = float(base.bounds[1, 1] / 1.8984375)
    shoulder_set = body[(base.vertices[:, 1] >= 1.45 * height_ratio) &
                        (base.vertices[:, 1] <= 1.56 * height_ratio) &
                        (np.abs(base.vertices[:, 0]) < .27)]
    if len(shoulder_set) < 30:
        raise FitError("invalid_profile", "shoulder landmarks unavailable")
    shoulder_x = float(np.ptp(shoulder_set[:, 0]) / 2)
    wrist_set = body[(base.vertices[:, 1] >= .88 * height_ratio) &
                     (base.vertices[:, 1] <= .99 * height_ratio) &
                     (base.vertices[:, 0] > .16)]
    wrist_x = float(np.quantile(wrist_set[:, 0], .65)) if len(wrist_set) > 20 else shoulder_x + .026
    torso_scale_x = 1.15 * shoulder_x / .24111
    mark = perf_counter()
    front_cage, back_cage = _cage(body)
    envelope_time = (perf_counter() - mark) * 1000

    def deform(vertices: np.ndarray) -> np.ndarray:
        x, y, z = np.asarray(vertices, dtype=float).T
        torso_x = torso_scale_x * x
        torso_y = height_ratio * (1.26 + .74 * y)
        side = np.where(x < 0, -1.0, 1.0)
        ax = np.abs(x)
        src_start = np.array([.22, .20])
        src_end = np.array([.77, -.44])
        src_axis = src_end - src_start
        src_len = np.linalg.norm(src_axis)
        src_dir = src_axis / src_len
        src_perp = np.array([-src_dir[1], src_dir[0]])
        target_start = np.array([shoulder_x, 1.49 * height_ratio])
        target_end = np.array([wrist_x, .88 * height_ratio])
        target_axis = target_end - target_start
        target_dir = target_axis / np.linalg.norm(target_axis)
        target_perp = np.array([-target_dir[1], target_dir[0]])
        relative = np.column_stack((ax, y)) - src_start
        along = relative @ src_dir
        across = relative @ src_perp
        arm_xy = (target_start + along[:, None] * (np.linalg.norm(target_axis) / src_len) * target_dir
                  + across[:, None] * .35 * target_perp)
        weight = _smoothstep(.17, .29, ax)
        xx = torso_x * (1 - weight) + side * arm_xy[:, 0] * weight
        yy = torso_y * (1 - weight) + arm_xy[:, 1] * weight
        xy = np.column_stack((xx, yy))
        front_z = front_cage(xy) + .025
        back_z = back_cage(xy) - .025
        zz = np.where(z >= 0, np.maximum(front_z, back_z + .05), back_z)
        result = np.column_stack((xx, yy, zz))
        if not np.isfinite(result).all():
            raise FitError("invalid_geometry", "fitted vertices are non-finite")
        return result

    mark = perf_counter()
    fitted = trimesh.Scene()
    metrics = {}
    for name, mesh in source.geometry.items():
        derived = mesh.copy()
        derived.vertices = deform(mesh.vertices)
        tri = derived.vertices[derived.faces]
        area = np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)
        if (area <= 1e-12).any() or len(derived.vertices) != len(mesh.vertices) or len(derived.faces) != len(mesh.faces):
            raise FitError("invalid_geometry", "fit changed topology or introduced zero-area faces")
        if name == "garment_front" and not np.array_equal(derived.visual.uv, mesh.visual.uv):
            raise FitError("invalid_texture", "front UV coordinates changed")
        metrics[name] = {"vertices": len(derived.vertices), "triangles": len(derived.faces),
                         "minimum_twice_area": float(area.min())}
        fitted.add_geometry(derived, geom_name=name, node_name=name)
    deformation_time = (perf_counter() - mark) * 1000
    mark = perf_counter()
    glb = fitted.export(file_type="glb")
    exported = trimesh.load(io.BytesIO(glb), file_type="glb", force="scene")
    if _boundary_sizes(exported) != baseline_loops:
        raise FitError("invalid_topology", "fit changed neck, cuff or hem loops")
    if set(exported.geometry) != set(source.geometry) or exported.geometry["garment_front"].visual.kind != "texture":
        raise FitError("invalid_texture", "export lost primitives or approved front texture")
    export_time = (perf_counter() - mark) * 1000
    base_hash = BASE_SHA256[profile.base_family]
    profile_fp = profile_fingerprint(profile_id, base_hash)
    identity = {"canonical_asset_fingerprint": canonical_sidecar["asset_fingerprint"],
                "profile_id": profile_id, "profile_fingerprint": profile_fp,
                "fitter_version": FITTER_VERSION, "clearance_version": CLEARANCE_VERSION,
                "body_geometry_version": GEOMETRY_VERSION}
    fingerprint = digest(json.dumps(identity, sort_keys=True, separators=(",", ":")).encode())
    sidecar = {**identity, "asset_fingerprint": fingerprint, "glb_sha256": digest(glb),
               "glb_bytes": len(glb), "garment_id": canonical_sidecar.get("garment_id"),
               "category": "long_sleeve_top", "template": "long_sleeve_top_v1",
               "base_avatar_sha256": base_hash, "mesh": metrics,
               "boundary_loop_sizes": baseline_loops, "openings": sorted(canonical_sidecar["boundary_loops"]),
               "landmarks": {"shoulder_half_span": shoulder_x, "right_wrist_x": wrist_x,
                             "avatar_height_ratio": height_ratio},
               "timing_ms": {"profile_geometry": body_time, "envelope": envelope_time,
                             "deformation": deformation_time, "glb_export_and_validation": export_time,
                             "total": (perf_counter() - started) * 1000},
               "provenance_limitations": ["synthetic_profile", "static_pose", "front_only_garment",
                                           "unobserved_back", "non_watertight_body_envelope",
                                           "no_physics", "no_rigging", "no_avatar_animation"]}
    return FitResult(glb=glb, sidecar=sidecar)
