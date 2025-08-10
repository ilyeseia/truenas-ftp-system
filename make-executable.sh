#!/bin/bash

# ========================================
# Make all scripts executable
# ========================================

echo "Making all scripts executable..."

find ./scripts -name "*.sh" -exec chmod +x {} \;

chmod +x deploy-complete.sh 2>/dev/null || true
chmod +x deploy.sh 2>/dev/null || true

echo "Done! All scripts are now executable."
