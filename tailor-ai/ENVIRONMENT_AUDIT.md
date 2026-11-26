# Tailor AI Environment Audit

**Audit timestamp:** 2026-08-06 09:34:08 -04:00 (America/Toronto)  
**Audit scope:** Read-only Windows, hardware, storage, development-tool, and local-network inspection.  
**Workspace:** `C:\Textyle`; project records at `C:\Textyle\tailor-ai`.

## Evidence labels

- **Verified:** observed directly through a local read-only command.
- **Inference:** a conclusion supported by verified observations but not directly measured.
- **Recommendation:** an action for a later milestone; not performed here.
- **Undetermined:** unavailable through safe inspection or blocked by missing software.

## Operating system

| Finding | Evidence status | Result |
|---|---|---|
| Edition | Verified | Microsoft Windows 11 Home (`EditionID: Core`) |
| Version/build | Verified | Version 10.0.26200, display version 25H2, build 26200 |
| Architecture | Verified | 64-bit OS on an x64-based PC |
| PowerShell | Verified | Windows PowerShell 5.1.26100.8875, Desktop edition |
| Developer Mode | Undetermined | `AppModelUnlock` key was absent. This does not prove Developer Mode is disabled. It is not required for the proposed Python `venv` workflow. |
| Long paths | Verified | `LongPathsEnabled=True` in the filesystem registry setting. |
| Relevant environment state | Verified | `PATH` is set; WindowsApps is on it; OneDrive is configured; no active `VIRTUAL_ENV`, `CONDA_PREFIX`, `PYTHONPATH`, `CUDA_PATH`, `DOCKER_HOST`, or WSL distribution variable was found. |

**Inference:** Long-path risk is reduced at the OS level, but individual tools and Git must still support long paths. Keeping the repository path short remains prudent. The planned project path is outside the configured OneDrive directory, so synchronization conflicts are not expected.

## GPU

| Finding | Evidence status | Result |
|---|---|---|
| `nvidia-smi` | Verified | Works successfully. |
| GPU count | Verified | One GPU enumerated. |
| GPU | Verified | NVIDIA GeForce RTX 5080, WDDM driver model. This differs from the supplied RTX 5090 estimate. |
| VRAM | Verified | 16,303 MiB total; 1,408 MiB in use during the audit. |
| Driver | Verified | NVIDIA driver/KMD 610.88. |
| Driver-reported CUDA capability | Verified | CUDA UMD version 13.3. This is the maximum runtime level reported by the driver, not evidence of a standalone CUDA Toolkit installation. |
| Utilization/temperature | Verified | 4% GPU utilization and 40 C at the sampling time. |

**Compatibility assessment:** The RTX 5080 uses NVIDIA's Blackwell generation. NVIDIA documents first Blackwell toolkit support at CUDA 12.8. PyTorch 2.12 recommends CUDA 13.0+ wheels for Blackwell and lists Windows driver 580.88 as the minimum for its CUDA 13.0 wheel. The installed 610.88 driver is newer and reports CUDA 13.3, so it appears suitable for a current CUDA-enabled PyTorch binary. This is a compatibility inference, not a functional PyTorch test, because Python and PyTorch are not installed. Recheck the official selector when installing because wheel availability changes.

Official references reviewed:

- [PyTorch Start Locally](https://docs.pytorch.org/get-started/locally/)
- [PyTorch 2.12 release notes: CUDA wheel guidance](https://pytorch.org/blog/pytorch-2-12-release-blog/)
- [NVIDIA CUDA toolkit, driver, and architecture matrix](https://docs.nvidia.com/datacenter/tesla/drivers/cuda-toolkit-driver-and-architecture-matrix.html)

**Recommendation:** Do not install a standalone CUDA Toolkit for normal prebuilt PyTorch wheels. Use the CUDA runtime included with the selected PyTorch distribution unless a later native-extension or source-build requirement proves otherwise. Do not change the current NVIDIA driver in Milestone 0.

## CPU and RAM

| Finding | Evidence status | Result |
|---|---|---|
| CPU | Verified | AMD Ryzen 9 9900X 12-Core Processor |
| Cores/threads | Verified | 12 physical cores, 24 logical processors |
| RAM | Verified | 31.1 GiB usable total; 18.58 GiB available at audit time |
| Memory modules/speed | Verified | Two modules; 4800 MHz reported configured/rated speed |
| Virtualization | Verified | Firmware virtualization enabled; Windows reports a hypervisor present. |
| SLAT property | Verified with caveat | CIM reported `SecondLevelAddressTranslationExtensions=False`, which conflicts with the modern CPU/hypervisor observations and should not be treated as authoritative. |

**Assessment:** CPU and memory are adequate for image preprocessing, a lightweight transfer-learning workflow, and single-model experiments. With 32 GB-class RAM, avoid unnecessarily large in-memory dataset caches and excessive data-loader workers. GPU VRAM, rather than CPU capability, will determine practical batch size.

## Storage

| Drive | Filesystem | Device | Total | Free at audit | Role |
|---|---|---|---:|---:|---|
| C: | NTFS | WD Green SN3000 2TB, NVMe SSD | 1832.4 GiB volume | 1716.0 GiB | System drive and current workspace |
| D: | NTFS | FIKWOT FN501Pro 1TB, NVMe SSD | 953.9 GiB | 438.7 GiB | Additional local internal storage |

Both physical disks reported healthy. The approximately 600 GB estimate is not current: substantially more space is available across two NVMe SSDs. `C:\Textyle` is on the C: NVMe SSD, not under OneDrive. Reserving 100 GiB on C: still leaves approximately 1616 GiB available at the time of audit.

**Assessment:** There is ample space for a small public-data experiment, virtual environments, checkpoints, and caches while maintaining a 100 GiB reserve. This does not authorize dataset download. Later work should define retention and artifact budgets and avoid duplicating large archives across both drives.

## Python

| Finding | Evidence status | Result |
|---|---|---|
| `python`, `python3`, `py` | Verified | Not discoverable in the current shell. |
| Python versions | Undetermined/none found | No usable Python installation was found. |
| `pip`, `pip3` | Verified | Not discoverable. |
| Environment managers | Verified | Conda, Mamba, Micromamba, Poetry, `uv`, pipx, and virtualenv were not discoverable. |
| Microsoft Store aliases | Verified | `python.exe` and `python3.exe` aliases exist in WindowsApps, which is on `PATH`, but invoking `python` did not produce a usable interpreter in this shell. |
| `venv` readiness | Not ready | Cannot test until Python is installed. A standard project-local `venv` should work cleanly after a proper installation. |

**Missing prerequisite:** A supported 64-bit Python interpreter and pip.

**Recommendation:** Install 64-bit Python 3.12 from an authoritative source in Milestone 1, ensure the actual interpreter precedes or replaces the Store alias behavior, and create a project-local virtual environment. Python 3.12 is recommended because the current official PyTorch Windows page documents support through 3.12 and it is a conservative choice for PyTorch/FastAPI compatibility. Verify current support again at installation time. No Python installation or environment creation occurred in this milestone.

## Git and GitHub

| Finding | Evidence status | Result |
|---|---|---|
| Git | Verified | Not installed or not discoverable on `PATH`; version unavailable. |
| User-level Git configuration | Undetermined | Cannot query without a Git executable. No configuration was changed. |
| GitHub CLI | Verified | `gh` not installed or not discoverable. |
| Git LFS | Verified | Not installed or not discoverable. |
| Current folder repository state | Verified | `C:\Textyle` was empty at initial inspection, `.git` was absent, and Git root discovery could not run because Git is missing. It is not currently a repository. |

**Recommendation:** Git is required before repository work in Milestone 1. GitHub CLI is optional; Git LFS should be considered later only if the repository policy calls for tracking model artifacts, and large datasets should not be committed. Do not alter global identity or authentication without explicit user action.

## Docker and WSL

| Finding | Evidence status | Result |
|---|---|---|
| Docker Desktop | Verified | No installation found in common locations or installed-program records. |
| Docker CLI/daemon | Verified | `docker` is unavailable; Docker cannot be running through the normal CLI. |
| WSL executable | Verified | `C:\Windows\System32\wsl.exe` exists. |
| WSL platform/distributions | Verified | WSL reports that Windows Subsystem for Linux is not installed; no distributions are available. |
| WSL GPU access | Not applicable/undetermined | Cannot test because WSL is not installed. |

### Approach comparison

| Approach | Simplicity | GPU path | Portability | Recommendation now |
|---|---|---|---|---|
| Native Windows + `venv` | Highest for this computer | Direct supported PyTorch Windows CUDA wheels | Dependency lock files and later containerization provide a path outward | **Start here** |
| WSL2 | Adds Linux and filesystem/IDE operational overhead | Usually good with supported NVIDIA/WSL setup, but currently unavailable | Closer to Linux servers | Defer unless Linux-only dependencies or server parity justify it |
| Docker Desktop | Adds daemon, images, storage, WSL/Hyper-V considerations | GPU containers require additional validation | Strong runtime packaging consistency | Defer until an inference boundary exists |
| Hybrid | Native iteration plus later Docker validation | Direct native GPU during experimentation | Good eventual deployment validation | **Recommended lifecycle:** native first, Docker later |

**Recommendation:** Use a hybrid lifecycle: begin with native Windows plus a project-local Python 3.12 virtual environment, then add Docker packaging in a later milestone after the inference dependency boundary is stable. Do not install WSL merely for this project unless a concrete incompatibility appears. This minimizes setup and troubleshooting for the single AI student while retaining a deliberate portability path.

## Existing development tools

| Tool | Evidence status | Result |
|---|---|---|
| Visual Studio Code | Verified | Not found on `PATH`, in common install locations, or installed-program records. |
| Codex integration | Verified | Codex desktop application is installed and this audit is running within it; its executable is discoverable, although direct version execution was denied by the application sandbox. |
| Visual Studio / Build Tools | Verified | No installation, installer, or `cl` compiler found in common locations. |
| CMake / Ninja | Verified | Not discoverable. |
| Archive tools | Verified | Windows `tar`/bsdtar 3.8.4 is available; 7-Zip was not found. |
| curl | Verified | `curl.exe` 8.21.0 is available. |
| Git LFS | Verified | Not discoverable. |

**Assessment:** VS Code is optional because Codex is available. C++ build tools are not needed for ordinary prebuilt PyTorch wheels; install them only if a later dependency requires compilation. The built-in archive and HTTP tools are sufficient for basic project operations.

## Network and firewall

| Finding | Evidence status | Result |
|---|---|---|
| Active connection | Verified | `Ethernet 2`, Realtek PCIe GbE controller, up at 1 Gbps, private profile, IPv4 and IPv6 internet connectivity reported. |
| Wi-Fi | Verified | Qualcomm Wi-Fi 7 adapters were not active at audit time. |
| Firewall | Verified | Domain, Private, and Public firewall profiles are enabled. |
| Port 8000 | Verified | No local TCP listener was present at audit time. |

No public IP was queried, no external scanning was performed, and no ports, firewall rules, forwarding, tunnels, or router settings were changed.

## Overall compatibility assessment

**Hardware readiness: ready.** The CPU, RAM, NVMe capacity, and RTX 5080 are appropriate for the intended lightweight transfer-learning direction. The GPU driver appears compatible with current Blackwell-capable PyTorch binaries.

**Software readiness: not yet ready.** Python/pip and Git are missing. A functional PyTorch CUDA test cannot be run until a virtual environment and selected binary are installed in Milestone 1. VS Code and GitHub CLI are optional conveniences; Docker, WSL, a standalone CUDA Toolkit, and C++ build tools are not initial prerequisites.

## Missing dependencies and recommended priority

1. **Required before Milestone 1 implementation:** 64-bit Python 3.12 with pip; Git for Windows.
2. **Recommended convenience:** a preferred editor such as VS Code if Codex alone is insufficient.
3. **Optional/defer:** GitHub CLI, Git LFS, Docker Desktop, WSL2, Visual Studio Build Tools, CMake, Ninja, and 7-Zip.
4. **Do not install by default:** standalone CUDA Toolkit; first validate the runtime bundled with the chosen PyTorch wheel.

## Risks and limitations

- The supplied GPU specification was incorrect; planning must use the verified RTX 5080 and 16 GB VRAM.
- Driver compatibility is inferred from version/architecture documentation, not validated with `torch.cuda.is_available()`.
- Microsoft Store Python aliases may cause command-resolution confusion after Python installation.
- Windows 11 build 26200/25H2 is newer than some third-party installation documentation; verify installers at use time.
- The 32 GB-class RAM ceiling makes unbounded caching and worker counts risky.
- WDDM display usage consumes part of GPU VRAM and can introduce desktop-related contention.
- WSL and container GPU behavior remain untested because neither WSL nor Docker is installed.
- Developer Mode could not be conclusively determined; it is not currently required.
- Dataset legal status, size, class coverage, and download access were not evaluated beyond creating an empty register.
- Internet speed was not benchmarked; only local interface/link state was inspected.

## Actions recommended before Milestone 1

1. Obtain user approval for the exact Python 3.12 and Git installation sources and options.
2. Install Python 3.12 x64 with pip, resolve Store-alias command precedence, and verify `python`, `py`, and `pip` paths.
3. Install Git for Windows, then inspect/set repository-local behavior without changing global identity unless explicitly requested.
4. Create a project-local virtual environment; do not place it in OneDrive or commit it.
5. Recheck the official PyTorch selector and choose a stable Windows wheel with CUDA 13.0+ Blackwell support; do not install a standalone toolkit by default.
6. After installation, run small CPU/GPU tensor checks, report PyTorch's CUDA runtime, and confirm the RTX 5080 name and memory from Python.
7. Define repository hygiene, dependency locking, data/artifact locations, and the 100 GiB free-space guard before downloading data.
8. Review authoritative dataset licences and fill `LICENSE_REGISTER.md` before any dataset download.
9. Keep WSL and Docker deferred until a concrete need or packaging milestone.

No software was installed, no dataset was downloaded, no training was started, no API was implemented, and no system configuration was changed during this audit.

---

## Milestone 1 verification addendum — 2026-08-06

This addendum preserves the Milestone 0 observations above and records changes made and verified during Milestone 1.

### Installed foundation

| Finding | Verified result |
|---|---|
| Python | CPython 3.12.10, 64-bit |
| Global interpreter | `C:\Users\niaga\AppData\Local\Programs\Python\Python312\python.exe` |
| Python launcher | `C:\Users\niaga\AppData\Local\Programs\Python\Launcher\py.exe` |
| Project interpreter | `C:\Textyle\tailor-ai\.venv\Scripts\python.exe` |
| Global pip | 25.0.1; no global project packages installed after rollback verification |
| Project pip/tooling | pip 26.2.1, setuptools 83.0.0, wheel 0.47.0 |
| Git | Git for Windows 2.55.0.windows.3 at `C:\Program Files\Git\cmd\git.exe` |
| Git identity | No global username/email configured |
| Repository | Local `main` repository; no commits and no remotes |
| PyTorch | 2.13.0+cu130, stable official CUDA build |
| torchvision | 0.28.0+cu130 |
| Bundled CUDA runtime | 13.0 |
| cuDNN | Raw version 92000 (9.2.0) |
| Development checks | pytest 9.1.1 and Ruff 0.16.1 in `.venv` |

### GPU acceptance evidence

| Check | Result |
|---|---|
| CUDA available | `True` |
| Device count | 1 |
| Detected device | NVIDIA GeForce RTX 5080 |
| Device capability | 12.0 |
| Total memory visible to PyTorch | 15.92 GiB |
| CPU tensor operation | Passed; dot product 32.0 |
| CUDA tensor operation | Passed; sum of squares 30.0 |
| Modest CUDA matrix multiplication | Passed; finite output |
| Automatic mixed precision | Passed with `torch.float16` result |
| torchvision forward pass | Passed with `efficientnet_b0(weights=None)`, input `(1, 3, 64, 64)`, output `(1, 1000)` |
| Peak allocated memory | 66.58 MiB |
| Unsupported architecture/DLL/OOM errors | None |
| Post-test GPU state | `nvidia-smi` healthy; 44 C, 3% utilization at sample time |

Smoke timings are diagnostic samples only and are not performance claims.

### Repository and storage verification

- `.gitignore` excludes virtual environments, caches, root-level data/artifact directories, and model binaries without excluding a future source module named `models`.
- `.gitattributes` normalizes normal text to LF and preserves CRLF for `.bat` and `.cmd`.
- Repository-local `core.longpaths=true` and `core.autocrlf=false` are set.
- An exact user-level `safe.directory=C:/Textyle/tailor-ai` entry was required because the Codex workspace sandbox and signed-in user have different Windows owner SIDs. No identity was configured.
- `C:\TextyleData\tailor\data`, `artifacts`, and `cache` exist with marker files and no data/models.
- `D:\TailorArchive` could not be created because access to the D: root path was denied. No drive permissions were changed. The path remains documented for later user provisioning.

### Problems encountered and resolved

1. PowerShell initially blocked `Activate.ps1`. A process-only execution-policy bypass was used for Milestone commands; no persistent execution policy changed.
2. Because the first activation failed, one package-tool upgrade command reached global Python. It was immediately rolled back to the verified initial state: global pip 25.0.1 only; the newly added global setuptools, wheel, and packaging packages were removed.
3. The 1.9 GB official PyTorch wheel repeatedly hit TLS decrypt failures through both pip/OpenSSL and Windows Schannel. The same official wheel was completed with resumable range requests, retained at `C:\Textyle\installers`, hashed, and installed locally through pip. Package identity remained PyTorch 2.13.0+cu130.
4. The first Ruff run found closure-scope warnings in the smoke script. The implementation was corrected without changing test intent; the final Ruff run passed.

### Remaining risks

- New PowerShell sessions may need a process-only activation workaround unless the user later chooses an appropriate signed-script execution policy; no persistent change is required to run `.venv\Scripts\python.exe` directly.
- The recurrent TLS decrypt fault may affect future very large downloads and should be diagnosed separately before dataset acquisition.
- The environment lock contains a local file URI for the retained PyTorch wheel because that exact wheel was installed locally after transport failures; `requirements/base.txt` remains the portable authoritative installation definition.
- D: archive provisioning remains incomplete because of root permission denial.
- This milestone verifies only environment functionality, not model accuracy, sustained thermals, training stability, or production deployment.

No dataset was downloaded, no pretrained weights were downloaded, no model was trained, no API or Docker configuration was implemented, no remote was created, and no commit was made in Milestone 1.
