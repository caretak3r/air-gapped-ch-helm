#!/bin/bash
set -e

echo "Uninstalling release..."
helm uninstall control-plane || true
echo "Cleaned up."
