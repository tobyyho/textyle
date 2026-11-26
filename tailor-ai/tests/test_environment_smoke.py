"""Small repeatable CPU and RTX 5080 environment acceptance tests."""

import sys

import torch
import torchvision
from torchvision.models import efficientnet_b0


def test_python_and_framework_imports() -> None:
    assert sys.version_info[:2] == (3, 12)
    assert torch.__version__
    assert torchvision.__version__


def test_cpu_tensor_operation() -> None:
    result = torch.tensor([1.0, 2.0, 3.0]).sum().item()
    assert result == 6.0


def test_cuda_device_and_tensor_operation() -> None:
    assert torch.cuda.is_available()
    assert torch.cuda.device_count() >= 1
    assert "RTX 5080" in torch.cuda.get_device_name(0)

    values = torch.tensor([1.0, 2.0, 3.0], device="cuda")
    result = (values * 2).sum().item()
    assert abs(result - 12.0) < 1e-6


def test_torchvision_cuda_forward_without_weights() -> None:
    model = efficientnet_b0(weights=None).eval().to("cuda")
    model_input = torch.zeros((1, 3, 64, 64), device="cuda")
    with torch.inference_mode():
        output = model(model_input)

    assert output.shape == (1, 1000)
    assert torch.isfinite(output).all().item()
