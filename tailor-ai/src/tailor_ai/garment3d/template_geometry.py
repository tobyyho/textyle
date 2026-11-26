"""Versioned canonical long-sleeve topology and bounded mask-landmark deformation.

No pretrained model or per-mask-pixel topology generation is used here.
"""

from __future__ import annotations

import numpy as np
from scipy.interpolate import RBFInterpolator

CONTROLS = [
    ("neck_left", (455, 254)),
    ("shoulder_left", (400, 260)),
    ("outer_left_1", (335, 295)),
    ("outer_left_2", (270, 360)),
    ("outer_left_3", (205, 475)),
    ("outer_left_4", (140, 610)),
    ("cuff_outer_left", (85, 721)),
    ("cuff_inner_left", (150, 760)),
    ("inner_left_1", (205, 650)),
    ("inner_left_2", (260, 535)),
    ("inner_left_3", (315, 440)),
    ("armpit_left", (343, 408)),
    ("side_left_1", (366, 500)),
    ("side_left_2", (360, 620)),
    ("hem_left", (350, 720)),
    ("hem_mid", (512, 727)),
    ("hem_right", (666, 720)),
    ("side_right_2", (655, 620)),
    ("side_right_1", (655, 500)),
    ("armpit_right", (674, 413)),
    ("inner_right_3", (710, 455)),
    ("inner_right_2", (765, 555)),
    ("inner_right_1", (825, 665)),
    ("cuff_inner_right", (875, 775)),
    ("cuff_outer_right", (940, 746)),
    ("outer_right_4", (885, 620)),
    ("outer_right_3", (825, 485)),
    ("outer_right_2", (755, 370)),
    ("outer_right_1", (685, 295)),
    ("shoulder_right", (620, 260)),
    ("neck_right", (570, 254)),
    ("neck_mid_right", (548, 305)),
    ("neck_center", (512, 329)),
    ("neck_mid_left", (476, 305)),
]

OPEN_AFTER = {
    "cuff_outer_left": "left_cuff",
    "hem_left": "hem",
    "hem_mid": "hem",
    "cuff_inner_right": "right_cuff",
    "neck_right": "neck",
    "neck_mid_right": "neck",
    "neck_center": "neck",
    "neck_mid_left": "neck",
}


def polygon_area(points: np.ndarray) -> float:
    return float(np.sum(points[:, 0] * np.roll(points[:, 1], -1) - points[:, 1] * np.roll(points[:, 0], -1)) / 2)


def _runs(indices: np.ndarray) -> list[np.ndarray]:
    if len(indices) == 0:
        return []
    return [run for run in np.split(indices, np.where(np.diff(indices) > 1)[0] + 1) if len(run) >= 6]


def detect_controls(mask: np.ndarray) -> tuple[np.ndarray, dict]:
    """Fit fixed semantic controls with bounded row/column mask scans."""
    assert mask.ndim == 2 and mask.shape == (1024, 1024)
    yy, xx = np.where(mask)
    assert len(xx) > 10000
    left, right, top, bottom = int(xx.min()), int(xx.max()), int(yy.min()), int(yy.max())
    cx = (left + right) / 2

    def central_run(y: int) -> tuple[int, int]:
        runs = _runs(np.flatnonzero(mask[y]))
        center = [r for r in runs if r[0] <= cx <= r[-1]]
        if not center:
            center = [max(runs, key=len)]
        return int(center[0][0]), int(center[0][-1])

    hem_row = bottom - max(55, round((bottom - top) * 0.12))
    torso_l, torso_r = central_run(hem_row)
    torso_width = torso_r - torso_l
    assert 200 <= torso_width <= 500

    split = None
    for y in range(top + 50, min(top + 270, bottom - 120)):
        runs = _runs(np.flatnonzero(mask[y]))
        if len(runs) >= 3 and runs[0][-1] < cx - 50 and runs[-1][0] > cx + 50:
            split = (y, runs[0], runs[1], runs[-1])
            break
    assert split is not None, "Cannot distinguish both sleeves from torso"
    split_y, left_arm, middle, right_arm = split
    armpit_l = ((int(left_arm[-1]) + int(middle[0])) / 2, split_y)
    armpit_r = ((int(middle[-1]) + int(right_arm[0])) / 2, split_y)

    def mapped_x(reference_x: int) -> int:
        return int(round(left + (reference_x - 85) / (940 - 85) * (right - left)))

    def top_at(x: int) -> int:
        values = np.flatnonzero(mask[:, x])
        assert len(values) > 0, ("top", x)
        return int(values[0])

    def bottom_at(x: int) -> int:
        values = np.flatnonzero(mask[:, x])
        assert len(values) > 0, ("bottom", x)
        return int(values[-1])

    target: dict[str, tuple[float, float]] = {}
    shoulder_l = int(round(cx - 0.36 * torso_width))
    shoulder_r = int(round(cx + 0.36 * torso_width))
    neck_l = int(round(cx - 0.18 * torso_width))
    neck_r = int(round(cx + 0.18 * torso_width))
    neck_depth = top_at(int(round(cx))) + 0.19 * torso_width
    target["neck_left"] = (neck_l, top_at(neck_l))
    target["neck_right"] = (neck_r, top_at(neck_r))
    target["neck_center"] = (cx, neck_depth)
    target["neck_mid_left"] = ((neck_l + cx) / 2, (top_at(neck_l) + neck_depth) / 2 + 8)
    target["neck_mid_right"] = ((neck_r + cx) / 2, (top_at(neck_r) + neck_depth) / 2 + 8)
    target["shoulder_left"] = (shoulder_l, top_at(shoulder_l))
    target["shoulder_right"] = (shoulder_r, top_at(shoulder_r))

    for name, (reference_x, _) in CONTROLS:
        if name.startswith("outer_left_") or name.startswith("outer_right_"):
            x = mapped_x(reference_x)
            target[name] = (x, top_at(x))
        elif name.startswith("inner_left_") or name.startswith("inner_right_"):
            x = mapped_x(reference_x)
            target[name] = (x, bottom_at(x))

    target["cuff_outer_left"] = (left + 2, top_at(left + 2))
    target["cuff_inner_left"] = (mapped_x(150), bottom_at(mapped_x(150)))
    target["cuff_outer_right"] = (right - 2, top_at(right - 2))
    target["cuff_inner_right"] = (mapped_x(875), bottom_at(mapped_x(875)))
    target["armpit_left"] = armpit_l
    target["armpit_right"] = armpit_r

    for y, suffix in ((500, "1"), (620, "2")):
        ly, ry = central_run(y)
        target[f"side_left_{suffix}"] = (ly, y)
        target[f"side_right_{suffix}"] = (ry, y)
    hem_l, hem_r = central_run(hem_row)
    target["hem_left"] = (hem_l, bottom_at(hem_l))
    target["hem_mid"] = (cx, bottom_at(int(round(cx))))
    target["hem_right"] = (hem_r, bottom_at(hem_r))

    names = [name for name, _ in CONTROLS]
    assert set(target) == set(names), set(names) - set(target)
    fitted = np.array([target[name] for name in names], dtype=np.float64)
    assert polygon_area(fitted) < 0, "Source controls must preserve polygon orientation"
    info = {
        "bbox_xyxy": [left, top, right, bottom],
        "torso_center_x": cx,
        "torso_width_px": torso_width,
        "first_three_run_row": split_y,
        "hem_sample_row": hem_row,
        "controls": {name: list(map(float, target[name])) for name in names},
        "front_neck_depth_is_semantic_template_estimate": True,
    }
    return fitted, info


def _cross(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    ab, ac = b - a, c - a
    return float(ab[0] * ac[1] - ab[1] * ac[0])


def _inside_triangle(p: np.ndarray, a: np.ndarray, b: np.ndarray, c: np.ndarray, sign: float) -> bool:
    return all(sign * value >= -1e-7 for value in (_cross(a, b, p), _cross(b, c, p), _cross(c, a, p)))


def ear_clip(points: np.ndarray) -> np.ndarray:
    """Deterministic simple-polygon triangulation; boundary order is retained."""
    remaining = list(range(len(points)))
    sign = 1 if polygon_area(points) > 0 else -1
    faces = []
    while len(remaining) > 3:
        for j in range(len(remaining)):
            a, b, c = remaining[j - 1], remaining[j], remaining[(j + 1) % len(remaining)]
            if sign * _cross(points[a], points[b], points[c]) <= 1e-7:
                continue
            if any(
                _inside_triangle(points[k], points[a], points[b], points[c], sign)
                for k in remaining if k not in (a, b, c)
            ):
                continue
            faces.append((a, b, c))
            del remaining[j]
            break
        else:
            raise RuntimeError("Canonical polygon could not be ear-clipped")
    faces.append(tuple(remaining))
    return np.array(faces, dtype=np.int64)


def subdivide_pair(canonical: np.ndarray, fitted: np.ndarray, faces: np.ndarray, tags: dict, rounds: int = 4):
    """Subdivide matching canonical/fitted topology, retaining opening tags."""
    canonical = canonical.tolist()
    fitted = fitted.tolist()
    faces = faces.tolist()
    for _ in range(rounds):
        midpoint: dict[tuple[int, int], int] = {}

        def mid(a: int, b: int) -> int:
            key = tuple(sorted((a, b)))
            if key not in midpoint:
                midpoint[key] = len(canonical)
                canonical.append(((np.array(canonical[a]) + canonical[b]) / 2).tolist())
                fitted.append(((np.array(fitted[a]) + fitted[b]) / 2).tolist())
            return midpoint[key]

        refined = []
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            refined.extend(((a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)))
        new_tags = {}
        for (a, b), tag in tags.items():
            m = mid(a, b)
            new_tags[tuple(sorted((a, m)))] = tag
            new_tags[tuple(sorted((m, b)))] = tag
        faces, tags = refined, new_tags
    return np.array(canonical), np.array(fitted), np.array(faces, dtype=np.int64), tags


def canonical_topology() -> tuple[np.ndarray, np.ndarray, dict]:
    names = [name for name, _ in CONTROLS]
    points = np.array([point for _, point in CONTROLS], dtype=np.float64)
    assert polygon_area(points) < 0
    faces = ear_clip(points)
    tags = {tuple(sorted((i, (i + 1) % len(points)))): OPEN_AFTER.get(name, "seam") for i, name in enumerate(names)}
    return points, faces, tags


def _inside_polygon(points: np.ndarray, polygon: np.ndarray) -> np.ndarray:
    """Vectorized odd-even test; points exactly on boundary are handled separately."""
    x, y = points[:, 0], points[:, 1]
    inside = np.zeros(len(points), dtype=bool)
    for a, b in zip(polygon, np.roll(polygon, -1, axis=0)):
        crossing = ((a[1] > y) != (b[1] > y)) & (
            x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1] + 1e-20) + a[0]
        )
        inside ^= crossing
    return inside


def _inside_or_on_polygon(points: np.ndarray, polygon: np.ndarray) -> np.ndarray:
    inside = _inside_polygon(points, polygon)
    for a, b in zip(polygon, np.roll(polygon, -1, axis=0)):
        delta = b - a
        t = np.clip(((points - a) @ delta) / (delta @ delta), 0, 1)
        gap = points - (a + t[:, None] * delta)
        inside |= np.sum(gap * gap, axis=1) < 1e-8
    return inside


def grid_template_mesh(
    canonical_controls: np.ndarray,
    front_controls: np.ndarray,
    back_controls: np.ndarray,
    control_tags: dict,
    step: float = 8.0,
):
    """Fixed canonical panel lattice, smoothly deformed by semantic controls.

    The lattice comes from a category template, never from source mask pixels.
    It deliberately trades subpixel outline fidelity for regular editability.
    """
    xs = np.arange(np.floor(canonical_controls[:, 0].min() / step) * step,
                   np.ceil(canonical_controls[:, 0].max() / step) * step + step, step)
    ys = np.arange(np.floor(canonical_controls[:, 1].min() / step) * step,
                   np.ceil(canonical_controls[:, 1].max() / step) * step + step, step)
    gx, gy = np.meshgrid(xs, ys)
    grid = np.stack((gx.ravel(), gy.ravel()), axis=1)
    inside = _inside_or_on_polygon(grid, canonical_controls)
    nx, ny = len(xs), len(ys)
    faces = []
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            b, c, d = a + 1, a + nx + 1, a + nx
            for face in ((a, c, b), (a, d, c)):
                if all(inside[v] for v in face):
                    faces.append(face)
    faces = np.asarray(faces, dtype=np.int64)
    used, faces = np.unique(faces, return_inverse=True)
    canonical = grid[used]
    faces = faces.reshape(-1, 3)

    front_displacement = RBFInterpolator(
        canonical_controls, front_controls - canonical_controls,
        kernel="thin_plate_spline", smoothing=2.0
    )(canonical)
    back_displacement = RBFInterpolator(
        canonical_controls, back_controls - canonical_controls,
        kernel="thin_plate_spline", smoothing=2.0
    )(canonical)
    front = canonical + front_displacement
    back = canonical + back_displacement
    assert all(polygon_area(front[face]) < -1e-7 for face in faces)
    assert all(polygon_area(back[face]) < -1e-7 for face in faces)

    face_edges = np.sort(np.vstack((faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]])), axis=1)
    edges, counts = np.unique(face_edges, axis=0, return_counts=True)
    assert np.max(counts) <= 2
    boundary = edges[counts == 1]
    tags = {}
    for a, b in boundary:
        midpoint = (canonical[a] + canonical[b]) / 2
        distances = []
        for p, q in zip(canonical_controls, np.roll(canonical_controls, -1, axis=0)):
            delta = q - p
            t = np.clip(((midpoint - p) @ delta) / (delta @ delta), 0, 1)
            distances.append(np.linalg.norm(midpoint - (p + t * delta)))
        segment = int(np.argmin(distances))
        tags[(int(a), int(b))] = control_tags[tuple(sorted((segment, (segment + 1) % len(canonical_controls))))]

    return canonical, front, back, faces, tags, {
        "canonical_grid_step_px": step,
        "canonical_grid_vertices": len(canonical),
        "canonical_grid_triangles": len(faces),
        "boundary_vertices": len(tags),
        "source_deformation": "thin-plate RBF from 34 semantic controls; no per-mask-pixel topology",
    }


