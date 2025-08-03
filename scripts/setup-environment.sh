# ========================================
# scripts/setup-environment.sh
# ========================================
#!/bin/bash
echo "=== Configuration de l'environnement TrueNAS + FTP ==="

# Créer la structure des dossiers
mkdir -p {scripts,logs,downloads,uploads,dashboard,truenas-config}
mkdir -p truenas-data/{config,pool/{downloads,uploads,archive,temp}}

# Permissions
chmod -R 755 truenas-data/
chmod +x scripts/*.sh

echo "Structure créée:"
tree -L 3 .
