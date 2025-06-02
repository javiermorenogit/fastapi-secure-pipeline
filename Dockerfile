# --------------------------------------------------
# Dockerfile para tu aplicación FastAPI (runtime)
# --------------------------------------------------

FROM python:3.11-slim

# 1) Creamos un usuario sin privilegios
RUN adduser --disabled-password --gecos '' appuser

USER appuser

# 2) Aseguramos que ~/.local/bin esté en PATH
ENV PATH=/home/appuser/.local/bin:$PATH

WORKDIR /app

# 3) Copiamos requirements.txt y preinstalamos las dependencias en ~/.local
COPY --chown=appuser:appuser requirements.txt .
RUN python3 -m pip install --user --no-cache-dir -r requirements.txt

# 4) Copiamos el código de la aplicación
COPY --chown=appuser:appuser app /app/app

# 5) Exponemos el puerto 8000 para uvicorn
EXPOSE 8000

# 6) Comando por defecto al arrancar el contenedor
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
