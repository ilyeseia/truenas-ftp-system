# ========================================
# scripts/cleanup-truenas.sh
# ========================================
#!/bin/sh
echo "=== Nettoyage TrueNAS ==="

# Supprimer les fichiers temporaires
find /truenas/temp -type f -mtime +1 -delete 2>/dev/null
echo "Fichiers temporaires supprimés"

# Supprimer les doublons
find /truenas/downloads -type f -name "*.part" -delete 2>/dev/null
find /truenas/downloads -type f -name "*.tmp" -delete 2>/dev/null
echo "Fichiers partiels supprimés"

# Compresser les anciens logs
find /logs -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null
echo "Logs anciens compressés"

echo "Nettoyage terminé!"
