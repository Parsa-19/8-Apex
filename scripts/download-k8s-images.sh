
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

K8S_VERSION="v1.36.2"
CONTAINERD_NAMESPACE="k8s.io"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="${SCRIPT_DIR}/kubeadm/tar"
IMAGE_LIST="${SCRIPT_DIR}/kubeadm/images.txt"

# Use the containerd 2.x ctr binary
CTR="${CTR:-/usr/local/bin/ctr}"

# kubeadm must correspond to Kubernetes v1.36.2
KUBEADM="${KUBEADM:-/usr/local/bin/kubeadm}"

# ============================================================
# Checks
# ============================================================

echo "============================================================"
echo " Kubernetes ${K8S_VERSION} offline image preparation"
echo "============================================================"

if [[ ! -x "${KUBEADM}" ]]; then
    echo "ERROR: kubeadm not found at:"
    echo "  ${KUBEADM}"
    echo
    echo "Set KUBEADM=/path/to/kubeadm if necessary."
    exit 1
fi

if [[ ! -x "${CTR}" ]]; then
    echo "ERROR: ctr not found at:"
    echo "  ${CTR}"
    echo
    echo "Set CTR=/path/to/ctr if necessary."
    exit 1
fi

# ============================================================
# Prepare directories
# ============================================================

mkdir -p "${IMAGE_DIR}"

# ============================================================
# Generate exact image list from kubeadm
# ============================================================

echo
echo "[1/4] Generating image list from kubeadm..."

"${KUBEADM}" config images list \
    --kubernetes-version="${K8S_VERSION}" \
    > "${IMAGE_LIST}"

echo
echo "Images required by kubeadm:"
cat "${IMAGE_LIST}"

# ============================================================
# Pull images
# ============================================================

echo
echo "[2/4] Pulling images into containerd namespace:"
echo "      ${CONTAINERD_NAMESPACE}"
echo

while IFS= read -r IMAGE; do

    [[ -z "${IMAGE}" ]] && continue

    echo "------------------------------------------------------------"
    echo "Pulling:"
    echo "  ${IMAGE}"
    echo "------------------------------------------------------------"

    "${CTR}" \
        -n "${CONTAINERD_NAMESPACE}" \
        images pull \
        "${IMAGE}"

done < "${IMAGE_LIST}"

# ============================================================
# Export images
# ============================================================

echo
echo "[3/4] Exporting images to tar files..."
echo

while IFS= read -r IMAGE; do

    [[ -z "${IMAGE}" ]] && continue

    # Remove registry/repository characters that are inconvenient
    # in filenames.
    FILENAME="$(echo "${IMAGE}" \
        | sed 's#/#-#g' \
        | sed 's#:#-#g' \
        | sed 's#@#-#g')"

    TAR_FILE="${IMAGE_DIR}/${FILENAME}.tar"

    echo "Exporting:"
    echo "  ${IMAGE}"
    echo "-> ${TAR_FILE}"

    "${CTR}" \
        -n "${CONTAINERD_NAMESPACE}" \
        images export \
        "${TAR_FILE}" \
        "${IMAGE}"

done < "${IMAGE_LIST}"

# ============================================================
# Verify
# ============================================================

echo
echo "[4/4] Generated files:"
echo

ls -lh "${IMAGE_DIR}"

echo
echo "============================================================"
echo " Image preparation complete"
echo "============================================================"

echo
echo "Image list:"
cat "${IMAGE_LIST}"

echo
echo "Tar files:"
find "${IMAGE_DIR}" -maxdepth 1 -type f -name '*.tar' -printf '%f\n' | sort
