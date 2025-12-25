FROM pytorch/pytorch:2.1.2-cuda11.8-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# System deps:
# - build-essential: for any packages that may need compilation (e.g., pycocotools)
# - libglib2.0-0: OpenCV runtime dep
# - libgdal-dev + gdal-bin: geopandas/pyproj stack (if you actually use GDAL-backed features)
# - curl: misc / debugging
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libgdal-dev \
    gdal-bin \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /opt/program

# Ensure we use the system python in this image
# (Optional but helps avoid uv choosing anything odd)
ENV VIRTUAL_ENV=/opt/venv
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements first for better layer caching
COPY requirements.txt ./

# Install dependencies (CPU/GPU-agnostic Python deps from PyPI)
RUN uv pip install --no-cache -r requirements.txt

# Copy the application code
COPY . .

ENV PYTHONPATH=/opt/program
ENV OPENBLAS_NUM_THREADS=1

EXPOSE 8080

# Run the API server
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1", "--backlog", "10"]
