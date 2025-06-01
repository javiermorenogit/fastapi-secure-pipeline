#!/usr/bin/env bash
echo "▶️  Deploy paso omitido (entorno dev)"
exit 0



#!/usr/bin/env bash
set -e

echo "Desplegando a Railway…"
railway login --token "$RAILWAY_TOKEN"
railway up --service fastapi-app
