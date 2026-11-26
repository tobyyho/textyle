"""Verify Tailor's native Windows Python and CUDA environment without training."""

from __future__ import annotations

import gc
import platform
import sys
import time
from functools import partial


def require_python_312() -> None:
    """Fail clearly when the interpreter is not the selected project version."""
    if sys.version_info[:2] != (3, 12):
        raise RuntimeError(f"Python 3.12 is required; found {sys.version.split()[0]}")


def synchronize_and_time(operation) -> tuple[object, float]:
    """Time one CUDA operation after synchronizing, as a smoke measurement only."""
    import torch

    torch.cuda.synchronize()
    started = time.perf_counter()
    result = operation()
    torch.cuda.synchronize()
    return result, time.perf_counter() - started


def run_verification() -> None:
    """Run required CPU, CUDA, AMP, and torchvision smoke checks."""
    require_python_312()

    import torch
    import torchvision
    from torchvision.models import efficientnet_b0

    print(f"Python version: {sys.version.split()[0]}")
    print(f"Python executable: {sys.executable}")
    print(f"Platform: {platform.platform()}")
    print(f"Architecture: {platform.architecture()[0]}")
    print(f"torch version: {torch.__version__}")
    print(f"torchvision version: {torchvision.__version__}")
    print(f"PyTorch CUDA runtime: {torch.version.cuda}")
    print(f"cuDNN version: {torch.backends.cudnn.version()}")

    cpu_left = torch.tensor([1.0, 2.0, 3.0])
    cpu_right = torch.tensor([4.0, 5.0, 6.0])
    cpu_result = torch.dot(cpu_left, cpu_right).item()
    if cpu_result != 32.0:
        raise RuntimeError(f"CPU tensor result was unexpected: {cpu_result}")
    print(f"CPU tensor smoke: PASS (dot={cpu_result:.1f})")

    cuda_available = torch.cuda.is_available()
    device_count = torch.cuda.device_count()
    print(f"CUDA available: {cuda_available}")
    print(f"CUDA device count: {device_count}")
    if not cuda_available or device_count < 1:
        raise RuntimeError("CUDA and at least one CUDA device are required for Milestone 1")

    device = torch.device("cuda:0")
    properties = torch.cuda.get_device_properties(device)
    capability = torch.cuda.get_device_capability(device)
    print(f"CUDA device name: {properties.name}")
    print(f"CUDA device capability: {capability[0]}.{capability[1]}")
    print(f"Total GPU memory: {properties.total_memory / (1024**3):.2f} GiB")
    print(f"Current allocated GPU memory (start): {torch.cuda.memory_allocated() / (1024**2):.2f} MiB")

    torch.cuda.reset_peak_memory_stats(device)
    gpu_tensor = torch.arange(1, 5, dtype=torch.float32, device=device)
    gpu_result = (gpu_tensor.square().sum()).item()
    if gpu_result != 30.0:
        raise RuntimeError(f"CUDA tensor result was unexpected: {gpu_result}")
    print(f"CUDA tensor smoke: PASS (sum_of_squares={gpu_result:.1f})")

    matrix_a = torch.randn((1024, 1024), device=device)
    matrix_b = torch.randn((1024, 1024), device=device)
    matrix_result, matrix_elapsed = synchronize_and_time(partial(torch.matmul, matrix_a, matrix_b))
    if not torch.isfinite(matrix_result).all().item():
        raise RuntimeError("CUDA matrix multiplication produced non-finite values")
    print(f"CUDA matrix multiplication: PASS ({matrix_elapsed:.4f} s smoke measurement)")

    with torch.inference_mode():
        with torch.autocast(device_type="cuda", dtype=torch.float16):
            amp_result = torch.matmul(matrix_a[:128, :128], matrix_b[:128, :128])
    torch.cuda.synchronize()
    if not torch.isfinite(amp_result).all().item():
        raise RuntimeError("Automatic mixed-precision smoke produced non-finite values")
    print(f"Automatic mixed precision: PASS (dtype={amp_result.dtype})")

    model = efficientnet_b0(weights=None).eval().to(device)
    model_input = torch.randn((1, 3, 64, 64), device=device)

    with torch.inference_mode():
        model_output, model_elapsed = synchronize_and_time(partial(model, model_input))
    if model_output.shape != (1, 1000) or not torch.isfinite(model_output).all().item():
        raise RuntimeError(f"Unexpected torchvision output: shape={tuple(model_output.shape)}")
    print(
        "torchvision forward pass: PASS "
        f"(shape={tuple(model_output.shape)}, {model_elapsed:.4f} s smoke measurement)"
    )
    print(f"Current allocated GPU memory (end): {torch.cuda.memory_allocated() / (1024**2):.2f} MiB")
    print(f"Peak allocated GPU memory: {torch.cuda.max_memory_allocated() / (1024**2):.2f} MiB")

    del model_output, model_input, model
    del amp_result, matrix_result, matrix_a, matrix_b, gpu_tensor


def main() -> int:
    """Return a process status suitable for CI and local verification."""
    try:
        run_verification()
    except Exception as exc:
        print(f"ENVIRONMENT VERIFICATION FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    finally:
        gc.collect()
        try:
            import torch

            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception:
            pass

    print("Environment verification: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
