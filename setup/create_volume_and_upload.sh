#!/usr/bin/env bash
# Creates the UC catalog/schema/volume for the pipeline and uploads the sample
# repair-order PDFs. Run this once before `databricks bundle deploy`.
#
# Prereqs:
#   - Databricks CLI v0.230+  (databricks --version)
#   - Authenticated: databricks auth login --host https://<workspace>.cloud.databricks.com
#   - Privileges to CREATE CATALOG (or use an existing one — see CATALOG below)
#
# Usage:
#   CATALOG=main SCHEMA=subaru_ro ./setup/create_volume_and_upload.sh
set -euo pipefail

CATALOG="${CATALOG:-main}"
SCHEMA="${SCHEMA:-subaru_ro}"
VOLUME="${VOLUME:-ro_documents}"
PROFILE="${DATABRICKS_CONFIG_PROFILE:-DEFAULT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VOLUME_ROOT="/Volumes/${CATALOG}/${SCHEMA}/${VOLUME}"
SOURCE_DIR="${VOLUME_ROOT}/source_files"

echo "==> Using profile: ${PROFILE}"
echo "==> Target volume:  ${SOURCE_DIR}"

echo "==> Creating catalog / schema / volume (idempotent)"
databricks catalogs create "${CATALOG}" -p "${PROFILE}" 2>/dev/null || echo "    catalog ${CATALOG} already exists (ok)"
databricks schemas create "${SCHEMA}" "${CATALOG}" -p "${PROFILE}" 2>/dev/null || echo "    schema ${SCHEMA} already exists (ok)"
databricks volumes create "${CATALOG}" "${SCHEMA}" "${VOLUME}" MANAGED -p "${PROFILE}" 2>/dev/null || echo "    volume ${VOLUME} already exists (ok)"

echo "==> Uploading PDFs from sample_data/ to ${SOURCE_DIR}"
shopt -s nullglob 2>/dev/null || true
pdfs=("${REPO_ROOT}"/sample_data/*.pdf)
if [ ${#pdfs[@]} -eq 0 ]; then
  echo "    No PDFs found in sample_data/. Add your own repair-order PDFs there"
  echo "    and re-run this script (see sample_data/README.md)."
else
  for f in "${pdfs[@]}"; do
    base="$(basename "$f")"
    echo "    - ${base}"
    databricks fs cp "$f" "dbfs:${SOURCE_DIR}/${base}" --overwrite -p "${PROFILE}"
  done
fi

echo ""
echo "Done. Set this in databricks.yml (var.source_volume_path) or your deploy command:"
echo "    ${SOURCE_DIR}"
