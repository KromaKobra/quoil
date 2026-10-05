#!/usr/bin/env bash
# Run qs -c quoil. No build step and no plugin env needed — this wrapper exists so
# quoil exposes the same launch interface as mycaelestia, which is what lets
# ../shellctl start either one without special-casing.
set -euo pipefail

exec qs -c quoil "$@"
