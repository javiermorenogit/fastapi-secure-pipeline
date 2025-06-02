###############
# Stage 1: build
###############
FROM python:3.12-slim AS builder

WORKDIR /app

# Instalo dependencias del sistema mínimas para compilar wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

###############
# Stage 2: runtime
###############
FROM python:3.11-slim

# Crea usuario sin privilegios
RUN adduser --disabled-password --gecos '' appuser
USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH
WORKDIR /app

# Copio paquetes instalados por el builder
COPY --from=builder /root/.local /home/appuser/.local

# Copio solo el código necesario
COPY app /app/app
# Si tienes scripts o entrypoints:
# COPY scripts/entrypoint.sh /app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# jenkins-docker/Dockerfile
FROM jenkins/jenkins:lts-jdk17

USER root
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends docker.io git curl \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker jenkins   # agrega el usuario jenkins al grupo docker
USER jenkins