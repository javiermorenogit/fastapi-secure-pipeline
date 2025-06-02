#################################################
# Dockerfile (runtime) para FastAPI, basado en Alpine
#################################################
FROM python:3.11-alpine

USER root

# 1) Actualizo los paquetes de Alpine y agrego ca-certificates
RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
         ca-certificates \
         build-base    # (opcional, si alguna dependencia de Python necesita compilar)
    # Nota: aquí no necesitas rm -rf /var/lib/apt/lists/*, porque Alpine no lo usa

# 2) Creo usuario sin privilegios
RUN adduser -D -u 1000 appuser

USER appuser

# 3) Incluir ~/.local/bin en PATH para pip --user
ENV PATH=/home/appuser/.local/bin:$PATH

WORKDIR /app

# 4) Copio requirements.txt y actualizo pip+setuptools antes de instalar
COPY --chown=appuser:appuser requirements.txt .
RUN python3 -m pip install --upgrade pip setuptools \
    && python3 -m pip install --user --no-cache-dir -r requirements.txt

# 5) Copio el código de la aplicación
COPY --chown=appuser:appuser app/ /app/app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
