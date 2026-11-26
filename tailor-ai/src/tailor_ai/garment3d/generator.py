"""Deterministic, front-only canonical garment shell generation (M10 v1)."""

from __future__ import annotations

import hashlib
import io
import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from time import perf_counter

import numpy as np
import trimesh
from PIL import Image, ImageDraw
from trimesh.visual import TextureVisuals
from trimesh.visual.material import SimpleMaterial

from .template_geometry import (
    CONTROLS,
    canonical_topology,
    detect_controls,
    grid_template_mesh,
)

GENERATOR_VERSION = "template-garment-v1"
TEMPLATE_VERSION = "long_sleeve_top_v1"
EXTRACTOR_VERSION = "shirt-controls-v1"
FIT_VERSION = "canonical-lattice-rbf-v1"
DEPTH_VERSION = "normalized-depth-v1"
TEXTURE_VERSION = "front-pixel-uv-v1"
CANONICAL_VERSION = "textyle-garment-3d-v1"
EXPORTER_VERSION = "trimesh-glb-v1"
ASSET_VERSION = "canonical-garment-v1"
EXPECTED_OPENINGS = {"neck", "left_cuff", "right_cuff", "hem"}
MIN_ACCEPTANCE_IOU = 0.90
MAX_INPUT_BYTES = 10 * 1024 * 1024


class Garment3DError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False).encode("utf-8")


def asset_fingerprint(category: str, hashes: dict, versions: dict, parameters: dict) -> str:
    return digest(canonical_json({"category": category, "hashes": hashes,
                                  "versions": versions, "parameters": parameters}))


def _approval_fingerprint(identity: dict) -> str:
    # Matches Textyle's recursive-key-sorted JSON fingerprint convention.
    return digest(canonical_json({"view": "front", "accepted": True,
                                  "identity": identity}))


def validate_approval(source: bytes, front: bytes, mask: bytes,
                      approval: dict) -> dict[str, str]:
    if not all(0 < len(data) <= MAX_INPUT_BYTES for data in (source, front, mask)):
        raise Garment3DError("invalid_input", "missing or oversized image")
    identity = approval.get("identity")
    if not isinstance(identity, dict) or approval.get("view") != "front":
        raise Garment3DError("approval_mismatch", "front approval identity missing")
    if approval.get("candidate_accepted") is not True or approval.get("user_approved") is not True:
        raise Garment3DError("approval_mismatch", "candidate has no stored approval")
    hashes = {
        "source_image_sha256": digest(source),
        "normalized_image_sha256": digest(front),
        "mask_sha256": digest(mask),
    }
    if any(identity.get(field) != value for field, value in hashes.items()):
        raise Garment3DError("approval_mismatch", "asset hash differs from approved identity")
    if approval.get("approval_fingerprint") != _approval_fingerprint(identity):
        raise Garment3DError("approval_mismatch", "approval fingerprint invalid")
    return hashes


@dataclass(frozen=True)
class GeneratedGarment:
    glb: bytes
    sidecar: dict


class Garment3DGenerator:
    def generate(self, garment_id: str, category: str, source: bytes,
                 front: bytes, mask: bytes, approval: dict) -> GeneratedGarment:
        raise NotImplementedError


class TemplateGarment3DGeneratorV1(Garment3DGenerator):
    def generate(self, garment_id: str, category: str, source: bytes,
                 front: bytes, mask: bytes, approval: dict) -> GeneratedGarment:
        if category != "long_sleeve_top":
            raise Garment3DError("unsupported_category", "3D template not available for category")
        if not garment_id or len(garment_id) > 128 or any(c in garment_id for c in "/\\\r\n"):
            raise Garment3DError("invalid_input", "invalid garment id")
        times: dict[str, float] = {}
        started = perf_counter()
        hashes = validate_approval(source, front, mask, approval)
        try:
            with Image.open(io.BytesIO(front)) as image:
                rgba = image.convert("RGBA")
            with Image.open(io.BytesIO(mask)) as image:
                mask_array = np.asarray(image.convert("L")) > 127
        except Exception as exc:
            raise Garment3DError("invalid_input", "approved images cannot be decoded") from exc
        if rgba.size != (1024, 1024) or mask_array.shape != (1024, 1024):
            raise Garment3DError("invalid_input", "approved assets must be 1024x1024")
        mark = perf_counter()
        try:
            target, landmarks = detect_controls(mask_array)
        except (AssertionError, ValueError, IndexError) as exc:
            raise Garment3DError("invalid_silhouette", "shirt controls could not be extracted") from exc
        names = [name for name, _ in CONTROLS]
        polygon_image = Image.new("1", (1024, 1024), 0)
        ImageDraw.Draw(polygon_image).polygon([tuple(p) for p in target], fill=1)
        projection = np.asarray(polygon_image, dtype=bool)
        intersection = int(np.count_nonzero(projection & mask_array))
        union = int(np.count_nonzero(projection | mask_array))
        iou = intersection / union if union else 0.0
        if iou < MIN_ACCEPTANCE_IOU:
            raise Garment3DError("invalid_silhouette", "silhouette fit below frozen 0.90 gate")
        times["silhouette_analysis_ms"] = (perf_counter() - mark) * 1000

        mark = perf_counter()
        back_controls = target.copy()
        nc, nl, nr = [names.index(n) for n in ("neck_center", "neck_left", "neck_right")]
        lm, rm = [names.index(n) for n in ("neck_mid_left", "neck_mid_right")]
        back_controls[nc, 1] = min(back_controls[nl, 1], back_controls[nr, 1]) + .075 * landmarks["torso_width_px"]
        back_controls[lm, 1] = (back_controls[nl, 1] + back_controls[nc, 1]) / 2
        back_controls[rm, 1] = (back_controls[nr, 1] + back_controls[nc, 1]) / 2
        canonical_controls, _, base_tags = canonical_topology()
        try:
            _, front_xy, back_xy, faces, tags, fit_details = grid_template_mesh(
                canonical_controls, target, back_controls, base_tags)
        except (AssertionError, ValueError) as exc:
            raise Garment3DError("invalid_silhouette", "template fitting inverted or damaged geometry") from exc
        times["template_fit_ms"] = (perf_counter() - mark) * 1000

        mark = perf_counter()
        n = len(front_xy)
        all_xy = np.vstack((front_xy, back_xy))
        bounds_min, bounds_max = all_xy.min(axis=0), all_xy.max(axis=0)
        scale = 1.0 / float(bounds_max[1] - bounds_min[1])
        center_x = float((bounds_min[0] + bounds_max[0]) / 2)
        center_y = float((bounds_min[1] + bounds_max[1]) / 2)
        torso_center = landmarks["torso_center_x"]
        torso_width = landmarks["torso_width_px"]

        def panel(xy: np.ndarray, sign: int) -> np.ndarray:
            dome = np.clip(1 - ((xy[:, 0] - torso_center) / (.70 * torso_width)) ** 2, 0, 1)
            depth = .018 + .046 * dome
            return np.stack(((xy[:, 0] - center_x) * scale,
                             (center_y - xy[:, 1]) * scale, sign * depth), axis=1)

        front_xyz, back_xyz = panel(front_xy, +1), panel(back_xy, -1)
        vertices = np.vstack((front_xyz, back_xyz))
        front_faces = faces.copy()
        back_faces = faces[:, [2, 1, 0]] + n
        # The front panel has fixed winding. The seam uses its actual directed edge.
        directed: dict[tuple[int, int], tuple[int, int]] = {}
        for triangle in front_faces:
            for i in range(3):
                a, b = int(triangle[i]), int(triangle[(i + 1) % 3])
                directed[tuple(sorted((a, b)))] = (a, b)
        seam_faces = []
        for edge, tag in tags.items():
            if tag == "seam":
                a, b = directed[edge]
                seam_faces.extend(((a, n + b, b), (a, n + a, n + b)))
        seam_faces = np.asarray(seam_faces, dtype=np.int64)
        all_faces = np.vstack((front_faces, back_faces, seam_faces))
        logical = trimesh.Trimesh(vertices=vertices, faces=all_faces, process=False)
        times["depth_and_mesh_ms"] = (perf_counter() - mark) * 1000

        mark = perf_counter()
        loops, quality = _validate_mesh(logical, front_xy, n, center_x, target[names.index("hem_mid"), 1], torso_width)
        times["validation_ms"] = (perf_counter() - mark) * 1000
        mark = perf_counter()
        uv = np.stack((front_xy[:, 0] / 1024, 1 - front_xy[:, 1] / 1024), axis=1)
        if not np.isfinite(uv).all() or (uv < 0).any() or (uv > 1).any():
            raise Garment3DError("topology_failure", "invalid front UVs")
        material = SimpleMaterial(image=rgba, name="approved_front_photo")
        front_mesh = trimesh.Trimesh(vertices=front_xyz, faces=front_faces,
                                    visual=TextureVisuals(uv=uv, material=material), process=False)
        back_mesh = trimesh.Trimesh(vertices=back_xyz, faces=faces[:, [2, 1, 0]], process=False)
        back_mesh.visual.vertex_colors = [183, 183, 181, 255]
        seam_mesh = trimesh.Trimesh(vertices=vertices, faces=seam_faces, process=False)
        seam_mesh.visual.vertex_colors = [156, 156, 154, 255]
        scene = trimesh.Scene()
        scene.add_geometry(front_mesh, geom_name="garment_front", node_name="garment_front")
        scene.add_geometry(back_mesh, geom_name="garment_back", node_name="garment_back")
        scene.add_geometry(seam_mesh, geom_name="garment_seams", node_name="garment_seams")
        times["texture_projection_ms"] = (perf_counter() - mark) * 1000
        mark = perf_counter()
        try:
            glb = scene.export(file_type="glb")
            loaded = trimesh.load(io.BytesIO(glb), file_type="glb", force="scene")
            textured = [mesh for mesh in loaded.geometry.values() if mesh.visual.kind == "texture"]
            if len(loaded.geometry) != 3 or len(textured) != 1 or len(textured[0].visual.uv) != n:
                raise ValueError("GLB primitives or front texture missing")
            exported = loaded.to_geometry()
            rounded, remap = np.unique(np.round(exported.vertices, 6), axis=0,
                                       return_inverse=True)
            exported_faces = remap[exported.faces]
            exported_edges = np.sort(np.vstack((exported_faces[:, [0, 1]],
                                                exported_faces[:, [1, 2]],
                                                exported_faces[:, [2, 0]])), axis=1)
            exported_unique, exported_counts = np.unique(exported_edges, axis=0,
                                                          return_counts=True)
            if (exported_counts > 2).any() or int((exported_counts == 1).sum()) != sum(
                loop["vertices"] for loop in loops.values()
            ):
                raise ValueError("GLB changed semantic boundary topology")
            exported_boundary = exported_unique[exported_counts == 1]
            exported_adj: dict[int, list[int]] = defaultdict(list)
            for a, b in exported_boundary:
                exported_adj[int(a)].append(int(b))
                exported_adj[int(b)].append(int(a))
            if any(len(neighbors) != 2 for neighbors in exported_adj.values()):
                raise ValueError("GLB has a torn boundary")
            remaining = {tuple(map(int, edge)) for edge in exported_boundary}
            exported_loop_sizes = []
            while remaining:
                start, _ = min(remaining)
                prev, current, size = -1, start, 0
                while True:
                    size += 1
                    choices = exported_adj[current]
                    nxt = choices[0] if choices[0] != prev else choices[1]
                    remaining.discard(tuple(sorted((current, nxt))))
                    prev, current = current, nxt
                    if current == start:
                        break
                    if size > len(exported_boundary):
                        raise ValueError("GLB boundary does not close")
                exported_loop_sizes.append(size)
            if sorted(exported_loop_sizes) != sorted(loop["vertices"] for loop in loops.values()):
                raise ValueError("GLB opening loops differ from validated shell")
            span_y = float(rounded[:, 1].max() - rounded[:, 1].min())
            if abs(span_y - 1.0) > 2e-6 or not np.isfinite(rounded).all():
                raise ValueError("GLB changed canonical scale or finiteness")
        except Exception as exc:
            raise Garment3DError("export_failure", "canonical GLB export failed") from exc
        times["glb_export_and_parse_ms"] = (perf_counter() - mark) * 1000
        times["total_generation_ms"] = (perf_counter() - started) * 1000

        versions = {
            "generator": GENERATOR_VERSION, "template": TEMPLATE_VERSION,
            "extractor": EXTRACTOR_VERSION, "fit": FIT_VERSION,
            "depth": DEPTH_VERSION, "texture": TEXTURE_VERSION,
            "canonicalizer": CANONICAL_VERSION, "exporter": EXPORTER_VERSION,
        }
        parameters = {"grid_step_px": 8, "minimum_iou": MIN_ACCEPTANCE_IOU,
                      "depth_sleeve": .018, "depth_torso_add": .046,
                      "back_neck_fraction": .075}
        fingerprint = asset_fingerprint(category, hashes, versions, parameters)
        sidecar = {
            "asset_version": ASSET_VERSION, "garment_id": garment_id,
            "generated_at_utc": datetime.now(UTC).isoformat(),
            "category": category, "versions": versions,
            "input_hashes": hashes,
            "approval_fingerprint": approval["approval_fingerprint"],
            "asset_fingerprint": fingerprint,
            "logical_mesh_sha256": digest(vertices.astype("<f8").tobytes() + all_faces.astype("<i8").tobytes()),
            "glb_sha256": digest(glb), "glb_bytes": len(glb),
            "canonical_transform": {"x": "bounds_center_to_zero", "y": "bounds_center_to_zero",
                                    "z": "front_back_midpoint_zero", "vertical_span": 1.0},
            "scale_provenance": "normalized_template_not_measured_meters",
            "orientation": "+X garment right; +Y up; +Z photographed front",
            "front_geometry_provenance": "observed_silhouette",
            "back_geometry_provenance": "template_derived",
            "front_texture_provenance": "approved_normalized_rgba",
            "back_texture_provenance": "neutral_template_placeholder",
            "materials": ["approved_front_photo", "neutral_back_gray", "neutral_seam_gray"],
            "mesh": {"logical_vertices": len(vertices), "triangles": len(all_faces),
                     "silhouette_control_iou": iou,
                     "exported_boundary_edges": int((exported_counts == 1).sum()),
                     "exported_vertical_span": span_y,
                     **quality, **fit_details},
            "boundary_loops": loops,
            "validation_status": "passed",
            "timing_ms": times,
            "limitations": ["front_only", "synthetic_depth", "unobserved_back",
                            "normalized_scale", "no_avatar_fit", "no_rigging", "no_physics"],
        }
        return GeneratedGarment(glb, sidecar)


def _validate_mesh(mesh: trimesh.Trimesh, front_xy: np.ndarray, n: int,
                   center_x: float, hem_y: float, torso_width: float) -> tuple[dict, dict]:
    if not np.isfinite(mesh.vertices).all() or not np.isfinite(mesh.vertex_normals).all():
        raise Garment3DError("topology_failure", "non-finite geometry")
    if not mesh.is_winding_consistent or (mesh.area_faces < 1e-12).any():
        raise Garment3DError("topology_failure", "inverted or zero-area faces")
    if len(mesh.split(only_watertight=False)) != 1:
        raise Garment3DError("topology_failure", "disconnected garment shell")
    edges = np.sort(np.vstack((mesh.faces[:, [0, 1]], mesh.faces[:, [1, 2]],
                               mesh.faces[:, [2, 0]])), axis=1)
    unique, counts = np.unique(edges, axis=0, return_counts=True)
    if (counts > 2).any():
        raise Garment3DError("topology_failure", "non-manifold mesh edge")
    boundary = unique[counts == 1]
    adjacency: dict[int, list[int]] = defaultdict(list)
    for a, b in boundary:
        adjacency[int(a)].append(int(b))
        adjacency[int(b)].append(int(a))
    if any(len(neighbors) != 2 for neighbors in adjacency.values()):
        raise Garment3DError("topology_failure", "tear or branched boundary")
    unseen = {tuple(map(int, edge)) for edge in boundary}
    loops: dict[str, dict] = {}
    while unseen:
        start, _ = min(unseen)
        previous, current = -1, start
        path = []
        while True:
            path.append(current)
            choices = adjacency[current]
            nxt = choices[0] if choices[0] != previous else choices[1]
            unseen.discard(tuple(sorted((current, nxt))))
            previous, current = current, nxt
            if current == start:
                break
            if len(path) > len(boundary):
                raise Garment3DError("topology_failure", "unclosed boundary")
        xy = front_xy[np.asarray(path) % n]
        mx, my = xy.mean(axis=0)
        if mx < center_x - torso_width:
            label = "left_cuff"
        elif mx > center_x + torso_width:
            label = "right_cuff"
        elif my > hem_y - 40:
            label = "hem"
        else:
            label = "neck"
        if label in loops:
            raise Garment3DError("topology_failure", "unexpected extra boundary")
        loops[label] = {"vertices": len(path), "open": True,
                        "centroid": mesh.vertices[path].mean(axis=0).tolist()}
    if set(loops) != EXPECTED_OPENINGS:
        raise Garment3DError("topology_failure", "required garment opening missing")
    tri = mesh.vertices[mesh.faces]
    a, b, c = (np.linalg.norm(tri[:, i] - tri[:, j], axis=1)
               for i, j in ((1, 2), (0, 2), (0, 1)))
    ca = np.clip((b*b + c*c - a*a) / (2*b*c), -1, 1)
    cb = np.clip((a*a + c*c - b*b) / (2*a*c), -1, 1)
    aa, ab = np.arccos(ca), np.arccos(cb)
    smallest = np.rad2deg(np.minimum(np.minimum(aa, ab), np.pi - aa - ab))
    quality = {
        "winding_consistent": True, "connected_components": 1,
        "watertight": False, "nonmanifold_edges": 0, "zero_area_triangles": 0,
        "minimum_triangle_angle_degrees": float(smallest.min()),
        "triangles_below_5_degrees": int((smallest < 5).sum()),
        "inverted_faces": 0,
    }
    return loops, quality


TEMPLATE_REGISTRY: dict[str, type[Garment3DGenerator]] = {
    "long_sleeve_top": TemplateGarment3DGeneratorV1,
}


def generator_for(category: str) -> Garment3DGenerator:
    try:
        return TEMPLATE_REGISTRY[category]()
    except KeyError as exc:
        raise Garment3DError("unsupported_category", "3D template not available for category") from exc
