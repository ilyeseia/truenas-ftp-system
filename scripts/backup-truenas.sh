# ========================================
# scripts/backup-truenas.sh
# ========================================
#!/bin/sh
echo "=== Sauvegarde TrueNAS ==="

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/truenas/archive/backups"

mkdir -p $BACKUP_DIR

# Créer une archive des téléchargements importants
tar -czf "$BACKUP_DIR/downloads_$BACKUP_DATE.tar.gz" -C /truenas/downloads . 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Sauvegarde créée: downloads_$BACKUP_DATE.tar.gz"
else
    echo "❌ Erreur lors de la sauvegarde"
fi

# Nettoyer les anciennes sauvegardes (garder 30 jours)
find $BACKUP_DIR -name "downloads_*.tar.gz" -mtime +30 -delete 2>/dev/null

echo "Sauvegarde terminée!"
