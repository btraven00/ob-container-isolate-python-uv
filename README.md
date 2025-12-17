# Python Multi-Version Container with UV

Run Python modules with specific Python versions (3.6-3.13) in isolated containers.  
Ideal for omnibenchmark workflows and HPC clusters.

## Quick Start

**Prerequisites:** Docker, Apptainer/Singularity

```bash
# 1. Build the container (uses Python 3.8 by default)
make docker

# 2. Convert to Apptainer (for HPC)
make sif

# 3. Run your module
make run-docker              # Local testing with Docker
make run-apptainer           # Production on HPC
```

**Customize Python version:**
```bash
make docker LEGACY_PYTHON_VERSION=3.10    # Python 3.10
make docker LEGACY_PYTHON_VERSION=3.11    # Python 3.11
```

**Update dependencies:** Edit `requirements-module.txt`, then re-run. No rebuild needed!

---

## How It Works

1. **Container provides the Python environment** - Python 3.12 (main) + your chosen legacy version
2. **Your scripts and requirements are mounted** from host at runtime
3. **UV installs dependencies** automatically on first run (cached for speed)
4. **Your module executes** with the legacy Python version

---

## Configuration

### Python Version

Default is Python 3.8. Change it:
```bash
make docker LEGACY_PYTHON_VERSION=3.11
```

Want a precise version? Compile from source:
```bash
make docker BUILD_FROM_SOURCE=true LEGACY_PYTHON_VERSION=3.10.13
```

### Dependencies

Edit `requirements-module.txt`:
```
requests < 2.28
h5py==3.12.1
python-igraph
numpy>=1.20.0
```

Dependencies install at runtime. First run is slower, subsequent runs are fast (cached).[^1]

[^1]: For production, you can "freeze" dependencies at build time for instant startup (no cache mount needed). Trade-off: larger image, less flexibility. See "Build-Time Installation" in DETAILS.md.

### Multi-Arch Builds

```bash
# Build for both AMD64 and ARM64
make docker-multiarch REGISTRY=docker.io/yourusername
```

---

## For Omnibenchmark Users

This container solves the Python version conflict between omnibenchmark (requires Python 3.12) and legacy modules (may need older Python).

**Workflow:**
1. Build container with your required Python version
2. Convert to Apptainer SIF
3. Run via omnibenchmark - your module gets the right Python version

See [DETAILS.md](DETAILS.md) for advanced configuration and troubleshooting.

---

## Production Notes

- `run_entrypoint.py` is for testing only - mount your own scripts in production
- Mount UV cache (`-v $HOME/.cache/uv:/app/.uv-cache`) for faster repeated installs
- On HPC without cache mounting, uncomment build-time install in Dockerfile (see DETAILS.md)
