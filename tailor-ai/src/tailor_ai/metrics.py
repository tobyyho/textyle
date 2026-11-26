"""Dependency-free multiclass metrics and calibration calculations."""

from __future__ import annotations

from typing import Any

import torch
from torch import Tensor


def confusion_matrix(targets: Tensor, predictions: Tensor, classes: int) -> Tensor:
    """Return rows=true, columns=predicted counts."""
    indices = targets.to(torch.int64) * classes + predictions.to(torch.int64)
    return torch.bincount(indices, minlength=classes * classes).reshape(classes, classes)


def metrics_from_confusion(matrix: Tensor) -> dict[str, Any]:
    """Calculate per-class, macro, weighted, and accuracy metrics."""
    matrix = matrix.to(torch.float64)
    support = matrix.sum(1)
    predicted = matrix.sum(0)
    tp = matrix.diag()
    precision = torch.where(predicted > 0, tp / predicted, 0.0)
    recall = torch.where(support > 0, tp / support, 0.0)
    f1 = torch.where(precision + recall > 0, 2 * precision * recall / (precision + recall), 0.0)
    total = support.sum()
    weights = torch.where(total > 0, support / total, 0.0)
    return {"accuracy": float(tp.sum() / total) if total else 0.0, "macro_precision": float(precision.mean()), "macro_recall": float(recall.mean()), "macro_f1": float(f1.mean()), "weighted_precision": float((precision * weights).sum()), "weighted_recall": float((recall * weights).sum()), "weighted_f1": float((f1 * weights).sum()), "per_class": [{"precision": float(precision[i]), "recall": float(recall[i]), "f1": float(f1[i]), "support": int(support[i]), "true_positive": int(tp[i]), "false_positive": int(predicted[i] - tp[i]), "false_negative": int(support[i] - tp[i])} for i in range(len(support))]}


def expected_calibration_error(probabilities: Tensor, targets: Tensor, bins: int = 15) -> float:
    """Compute equal-width maximum-confidence ECE."""
    confidence, prediction = probabilities.max(1)
    correct = prediction.eq(targets)
    error = torch.tensor(0.0, dtype=torch.float64)
    boundaries = torch.linspace(0, 1, bins + 1, device=probabilities.device)
    for index in range(bins):
        mask = (confidence > boundaries[index]) & (confidence <= boundaries[index + 1])
        if mask.any():
            error += mask.float().mean().double() * (correct[mask].float().mean() - confidence[mask].mean()).abs().double()
    return float(error)


def brier_score(probabilities: Tensor, targets: Tensor) -> float:
    """Return mean multiclass Brier score."""
    one_hot = torch.nn.functional.one_hot(targets, probabilities.shape[1]).to(probabilities.dtype)
    return float(((probabilities - one_hot) ** 2).sum(1).mean())


def summarize(probabilities: Tensor, targets: Tensor) -> dict[str, Any]:
    """Calculate the full aggregate metric set."""
    predictions = probabilities.argmax(1)
    result = metrics_from_confusion(confusion_matrix(targets, predictions, probabilities.shape[1]))
    result.update(top_three_accuracy=float((probabilities.topk(3, 1).indices == targets[:, None]).any(1).float().mean()), mean_confidence=float(probabilities.max(1).values.mean()), ece=expected_calibration_error(probabilities, targets), brier_score=brier_score(probabilities, targets))
    return result
