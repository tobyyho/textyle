"""Bounded prompts in EXIF-oriented normalized source coordinates."""

from __future__ import annotations

import json
import math
from dataclasses import dataclass

from tailor_ai.inference.runtime import InputError

SPACE = "exif_oriented_normalized_v1"
VERSION = "box-points-v1"


@dataclass(frozen=True)
class Correction:
    box: tuple[float, ...] | None
    points: tuple[tuple[float, float, int], ...]

    @classmethod
    def parse(cls, value: str) -> Correction:
        if len(value) > 8192:
            raise InputError("correction instructions too large")
        try:
            obj = json.loads(value)
            if not isinstance(obj, dict) or set(obj) - {"coordinate_space", "box", "points"}:
                raise ValueError()
            if obj.get("coordinate_space") != SPACE:
                raise ValueError()
            def coordinate(number):
                if type(number) not in (int, float) or not math.isfinite(number) or not 0 <= number <= 1:
                    raise ValueError()
                return float(number)
            box = obj.get("box")
            if box is not None:
                if not isinstance(box, list) or len(box) != 4:
                    raise ValueError()
                box = tuple(coordinate(v) for v in box)
                if box[2] <= box[0] or box[3] <= box[1]:
                    raise ValueError()
            raw_points = obj.get("points", [])
            if not isinstance(raw_points, list) or len(raw_points) > 20:
                raise ValueError()
            points = []
            for point in raw_points:
                if not isinstance(point, dict) or set(point) != {"x", "y", "label"}:
                    raise ValueError()
                if type(point["label"]) is not int or point["label"] not in (0, 1):
                    raise ValueError()
                points.append((coordinate(point["x"]), coordinate(point["y"]), point["label"]))
            if box is None and not any(p[2] == 1 for p in points):
                raise ValueError()
            if any(a[:2] == b[:2] and a[2] != b[2] for a in points for b in points):
                raise ValueError()
            return cls(box, tuple(points))
        except (ValueError, TypeError, KeyError, OverflowError) as exc:
            raise InputError("invalid correction coordinates or prompts") from exc

    def pixels(self, width: int, height: int) -> tuple[list | None, list, list]:
        box = [value * (width - 1 if i % 2 == 0 else height - 1)
               for i, value in enumerate(self.box)] if self.box else None
        if box and (box[2] - box[0] < 2 or box[3] - box[1] < 2):
            raise InputError("correction box is too small")
        return box, [[x * (width - 1), y * (height - 1)] for x, y, _ in self.points], [p[2] for p in self.points]

    def to_dict(self) -> dict:
        return {"coordinate_space": SPACE, "box": list(self.box) if self.box else None,
                "points": [{"x": x, "y": y, "label": label} for x, y, label in self.points]}
