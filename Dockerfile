# Multi-stage build for slim final image
# Stage 1: Builder stage for source compilation (only used if BUILD_FROM_SOURCE=true)
FROM ubuntu:22.04 AS builder

ARG LEGACY_PYTHON_VERSION
ARG BUILD_FROM_SOURCE=false

# Create the directory so COPY won't fail even when not building from source
RUN mkdir -p /usr/local/python-legacy

# Install build dependencies and compile (only in builder stage when BUILD_FROM_SOURCE=true)
RUN if [ "$BUILD_FROM_SOURCE" = "true" ]; then \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        wget \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses5-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libffi-dev \
        liblzma-dev && \
    cd /tmp && \
    wget --no-check-certificate https://www.python.org/ftp/python/${LEGACY_PYTHON_VERSION}/Python-${LEGACY_PYTHON_VERSION}.tgz && \
    tar xzf Python-${LEGACY_PYTHON_VERSION}.tgz && \
    cd Python-${LEGACY_PYTHON_VERSION} && \
    ./configure --prefix=/usr/local/python-legacy --enable-optimizations --enable-shared && \
    make -j$(nproc) && \
    make altinstall && \
    cd / && \
    rm -rf /tmp/Python-${LEGACY_PYTHON_VERSION}*; \
fi

# Stage 2: Final slim image
FROM ubuntu:22.04

# Build arguments
# LEGACY_PYTHON_VERSION: major.minor for pre-built (e.g., "3.8", "3.10") or full version for source (e.g., "3.8.18")
# BUILD_FROM_SOURCE: set to "true" to compile from source (default: false, uses deadsnakes PPA)
ARG LEGACY_PYTHON_VERSION=3.8
ARG BUILD_FROM_SOURCE=false

ENV DEBIAN_FRONTEND=noninteractive

# Install common dependencies and add deadsnakes PPA
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    git \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y \
    python3.12 \
    python3.12-venv \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Option 1: Install pre-built Python from deadsnakes PPA (default, fast)
# PPA already added above, just install the requested version
# Note: distutils only available for Python < 3.12
RUN if [ "$BUILD_FROM_SOURCE" != "true" ]; then \
    apt-get update && \
    apt-get install -y \
        python${LEGACY_PYTHON_VERSION} \
        python${LEGACY_PYTHON_VERSION}-venv && \
    (apt-get install -y python${LEGACY_PYTHON_VERSION}-distutils 2>/dev/null || true) && \
    ln -sf /usr/bin/python${LEGACY_PYTHON_VERSION} /usr/local/bin/python-legacy && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*; \
fi

# Option 2: Copy compiled Python from builder stage and set up
RUN if [ "$BUILD_FROM_SOURCE" = "true" ]; then \
    apt-get update && \
    apt-get install -y \
        libssl3 \
        libreadline8 \
        libsqlite3-0 \
        libncursesw6 \
        libbz2-1.0 \
        liblzma5 \
        libffi8 && \
    rm -rf /var/lib/apt/lists/*; \
fi

# Copy from builder stage (will be empty dir if BUILD_FROM_SOURCE=false)
COPY --from=builder /usr/local/python-legacy /usr/local/python-legacy

RUN if [ "$BUILD_FROM_SOURCE" = "true" ]; then \
    PYTHON_MAJOR_MINOR=$(echo ${LEGACY_PYTHON_VERSION} | cut -d. -f1,2) && \
    ln -sf /usr/local/python-legacy/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python-legacy && \
    echo "/usr/local/python-legacy/lib" > /etc/ld.so.conf.d/python-legacy.conf && \
    ldconfig; \
fi

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app

COPY requirements-module.txt .

# Create cache directory for uv packages
RUN mkdir -p /app/.uv-cache

# Optional: Uncomment to install dependencies at build time (faster startup, less flexible)
# RUN uv pip install --python python-legacy --system -r /app/requirements-module.txt

# Make Python 3.12 the default for Snakemake compatibility
# Legacy scripts will use python-legacy with uv
ENV PATH="/usr/local/bin:$PATH" \
    UV_CACHE_DIR=/app/.uv-cache

# Copy only the entrypoint (legacy_script.py will be mounted at runtime)
COPY entrypoint.sh .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Verify Python 3.12 is default and legacy Python is accessible
RUN python --version && python-legacy --version && uv --version

# Define the delegating entrypoint
ENTRYPOINT ["./entrypoint.sh"]
