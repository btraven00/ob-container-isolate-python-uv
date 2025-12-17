# Python Multi-Version with UV & Apptainer

This module demonstrates how to bootstrap a configurable legacy Python environment
(Python >= 3.8) inside a container using the modern `uv` package manager. This is 
ideal for archiving scientific workflows or running legacy scripts on modern HPC 
clusters using Apptainer.

The motivation is to allow omnibenchmark users to run legacy Python scripts with 
specific Python versions and bypass a current limitation in omnibenchmark's use 
of snakemake, where the execution environment needs to be compatible with Python 
3.12 and the set of dependencies required by omnibenchmark itself.

This implementation uses `uv` for fast, reliable package installation instead of 
traditional virtualenv, and supports any Python version >= 3.8 (configurable via 
build arguments).

## Production Usage Note

**Important**: The `run_entrypoint.py` included in this repository is for testing 
purposes only. In production, your actual module scripts should be 
**mounted externally** from the host filesystem, not embedded in the container image.

This approach provides:
- **Flexibility**: Update scripts without rebuilding containers
- **Separation of concerns**: Container provides environment, host provides code
- **Easier debugging**: Scripts remain editable on the host


## Quickstart: Complete Workflow

For the complete omnibenchmark workflow with Python 2.7 legacy script support:

### Prerequisites
- **UV Package Manager**: Install from [Astral's UV](https://github.com/astral-sh/uv)
- **Docker** (for building)  
- **Apptainer/Singularity** (for execution)

## 1. Build the Docker Image

### Option A: Pre-built Python (Default, Fast)

Build with a pre-built Python version from deadsnakes PPA:

```bash
make docker                              # Uses Python 3.8 (default, pre-built)
make docker LEGACY_PYTHON_VERSION=3.9    # Uses Python 3.9
make docker LEGACY_PYTHON_VERSION=3.10   # Uses Python 3.10
make docker LEGACY_PYTHON_VERSION=3.11   # Uses Python 3.11
```

**Advantages**: 
- Very fast build times (no compilation)
- Excellent version coverage (Python 3.6-3.13 from deadsnakes PPA)
- Small final image size with multi-stage build

### Option B: Compile from Source (Precise Version Control)

Build with an exact Python version compiled from source:

```bash
make docker-from-source LEGACY_PYTHON_VERSION=3.8.18
make docker-from-source LEGACY_PYTHON_VERSION=3.10.13
```

Or manually:

```bash
make docker BUILD_FROM_SOURCE=true LEGACY_PYTHON_VERSION=3.8.18
```

**Advantages**: 
- Precise version control (e.g., 3.8.18 vs 3.8.19)
- Best for reproducibility
- Optimized builds (--enable-optimizations)
- Multi-stage build keeps final image slim

### Test the Build

Run it to test:

```bash
make run-docker
```

You should see output confirming the legacy Python version is running.

## 2. Convert to Apptainer (Singularity)

If you have apptainer installed on your machine (linux) or are running this on an HPC cluster, you can pull directly from your local Docker daemon or a registry.

Use the Makefile to convert to Apptainer SIF:

```bash
make sif
```

This will create `py-multi.sif` from your Docker image.

## 3. Run with Apptainer

Run with the UV cache mounted for faster package installation:

```bash
make run-apptainer
```

Or run manually with custom cache directory:

```bash
apptainer run --bind /path/to/cache:/app/.uv-cache py-multi.sif
```

You can also execute specific commands:

```bash
apptainer exec py-multi.sif python-legacy --version
apptainer exec py-multi.sif python3 --version
apptainer exec py-multi.sif uv --version
```

### Quick Setup

```bash
# 1. Build Docker image
make docker

# 2. Convert to Apptainer SIF
make sif

# 3. Run omnibenchmark with UV-managed dependencies
# but feel free to use any other env manager that floats your boat
./run-omnibenchmark.py
```

This workflow provides:
- **Modern Python 3.12**: For omnibenchmark/Snakemake compatibility
- **Configurable Legacy Python**: Default Python 3.8, configurable to any version >= 3.6
- **Fast Builds**: Pre-built binaries from deadsnakes PPA (or compile from source)
- **Slim Images**: Multi-stage build keeps final image size small
- **Fast Package Management**: UV manages both omnibenchmark and module dependencies
- **Cache Support**: Mount UV cache directory for faster repeated installations


## Verify Results

Check that your module script executed correctly:
```bash
cat out/single/module/default/module.test.txt
```

This should show the Python version and environment information from your module execution.

## Configuration Options

### Python Version

**Pre-built (default, fast)**:
```bash
make docker LEGACY_PYTHON_VERSION=3.10
make sif
```

**From source (precise)**:
```bash
make docker-from-source LEGACY_PYTHON_VERSION=3.10.13
make sif
```

### UV Cache Directory

Customize the UV cache location:

```bash
make run-apptainer UV_CACHE_DIR=/custom/cache/path
```

Or when running directly:

```bash
apptainer run --bind /custom/cache/path:/app/.uv-cache py-multi.sif
```

### Module Dependencies

Edit `requirements-module.txt` to specify the Python packages needed by your module script.

**How it works:**
- Dependencies are installed **at runtime** (not at build time) using `uv`
- The entrypoint reads `requirements-module.txt` from your **mounted directory** (e.g., `/mnt`)
- UV's cache is mounted for fast repeated installations
- This allows you to update dependencies without rebuilding the Docker image

**Example `requirements-module.txt`:**
```
requests < 2.28
h5py==3.12.1
python-igraph
numpy>=1.20.0
```

**Performance tip:**
To prevent reinstalling on every container start, UV uses the mounted cache directory (`UV_CACHE_DIR`). First run installs packages, subsequent runs are much faster thanks to caching.

**Runtime installation (default, flexible):**
1. Edit `requirements-module.txt` on your host
2. Run container: `make run-docker`
3. UV installs/updates packages automatically from mounted file
4. No image rebuild needed!
5. Fast with cache mounting (`-v $(UV_CACHE_DIR):/app/.uv-cache`)

**Build-time installation (faster startup, less flexible):**
If you're not mounting the UV cache (e.g., on HPC clusters), you can pre-install dependencies at build time for faster container startup:

Uncomment the install step in the Dockerfile:
```dockerfile
# Install module dependencies at build time (optional, for faster startup)
RUN uv pip install --python python-legacy --system -r /app/requirements-module.txt
```

Then rebuild:
```bash
make docker
```

**Trade-offs:**
- **Runtime install**: Flexible (change deps without rebuild), requires cache mount for performance
- **Build-time install**: Faster startup, but requires rebuild to change dependencies
