#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

IMAGE_DIR="/var/lib/k8s-image-cache"
CONTAINERD_NAMESPACE="k8s.io"
CTR="${CTR:-/usr/local/bin/ctr}"

# ============================================================
# Checks
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

if [[ ! -x "${CTR}" ]]; then
    echo "ERROR: ctr not found:"
    echo "  ${CTR}"
    exit 1
fi

if [[ ! -d "${IMAGE_DIR}" ]]; then
    echo "ERROR: Image directory does not exist:"
    echo "  ${IMAGE_DIR}"
    exit 1
fi

# ============================================================
# Find images
# ============================================================

mapfile -t IMAGE_TARS < <(
    find "${IMAGE_DIR}" \
        -maxdepth 1 \
        -type f \
        -name '*.tar' \
        -print \
        | sort
)

if [[ "${#IMAGE_TARS[@]}" -eq 0 ]]; then
    echo "ERROR: No image tar files found in:"
    echo "  ${IMAGE_DIR}"
    exit 1
fi

echo "============================================================"
echo " Kubernetes offline image import"
echo "============================================================"
echo
echo "Containerd namespace:"
echo "  ${CONTAINERD_NAMESPACE}"
echo
echo "Images found:"
printf '  %s\n' "${IMAGE_TARS[@]}"
echo

# ============================================================
# Import
# ============================================================

for TAR_FILE in "${IMAGE_TARS[@]}"; do

    echo "------------------------------------------------------------"
    echo "Importing:"
    echo "  ${TAR_FILE}"
    echo "------------------------------------------------------------"

    "${CTR}" \
        -n "${CONTAINERD_NAMESPACE}" \
        images import \
        "${TAR_FILE}"

    echo

done

# ============================================================
# Verify
# ============================================================

echo "============================================================"
echo "Images currently available to Kubernetes:"
echo "============================================================"

"${CTR}" \
    -n "${CONTAINERD_NAMESPACE}" \
    images list

echo
echo "============================================================"
echo "CRI images:"
echo "============================================================"

if command -v crictl >/dev/null 2>&1; then
    crictl images
else
    echo "crictl not found; skipping CRI verification."
fi

echo
echo "============================================================"
echo "Import complete"
echo "============================================================"