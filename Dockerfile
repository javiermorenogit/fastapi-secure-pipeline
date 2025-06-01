###############
# Stage 1: build
###############
FROM python:3.11-slim AS builder

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
COPY gunicorn_conf.py /app  # (si lo necesitas)
# Si tienes scripts o entrypoints:
# COPY scripts/entrypoint.sh /app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
