#!/usr/bin/env bash
set -e

IMAGE="$1"
SEVERITY="CRITICAL,HIGH"

trivy image --quiet --exit-code 1 --severity "$SEVERITY" "$IMAGE"