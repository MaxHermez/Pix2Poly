# Use NVIDIA CUDA base image with cuDNN
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install Python 3.11 and minimal system dependencies
# Note: The CUDA base image is Ubuntu 22.04 minimal - no Python included
# We need:
# - python3.11, python3.11-dev, python3.11-venv: Python runtime and dev headers
# - build-essential: C compiler for packages that need compilation (pycocotools, etc.)
# - libglib2.0-0: Required by opencv at runtime
# - libgdal-dev, gdal-bin: Required by geopandas/pyogrio for geospatial operations
# - curl: For downloading uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    build-essential \
    libglib2.0-0 \
    libgdal-dev \
    gdal-bin \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /opt/program

# Create virtual environment with Python 3.11
RUN uv venv /opt/venv --python python3.11
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements first for better layer caching
COPY requirements.txt .
COPY requirements-cu118.txt .

# install CUDA torch stack from PyTorch index
RUN uv pip install --no-cache -r requirements-cu118.txt

# Install Python dependencies using uv
RUN uv pip install --no-cache -r requirements.txt

# Copy the application code
COPY . .

# Set environment variables
ENV PYTHONPATH=/opt/program
ENV OPENBLAS_NUM_THREADS=1

# Expose the API port
EXPOSE 8080

# Run the API server directly
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1", "--backlog", "10"] 
