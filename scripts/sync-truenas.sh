# ========================================
# scripts/sync-truenas.sh
# ========================================
#!/bin/sh
echo "=== Synchronisation TrueNAS ==="

LOG_FILE="/logs/sync.log"
echo "[$(date)] Début synchronisation" >> $LOG_FILE

# Synchroniser downloads locaux vers TrueNAS
if [ -d "/downloads-local" ] && [ "$(ls -A /downloads-local 2>/dev/null)" ]; then
    echo "Sync: downloads-local → truenas/downloads"
    rsync -av --progress /downloads-local/ /truenas/downloads/
    echo "[$(date)] Sync downloads terminé" >> $LOG_FILE
fi

# Synchroniser uploads locaux vers TrueNAS
if [ -d "/uploads-local" ] && [ "$(ls -A /uploads-local 2>/dev/null)" ]; then
    echo "Sync: uploads-local → truenas/uploads"
    rsync -av --progress /uploads-local/ /truenas/uploads/
    echo "[$(date)] Sync uploads terminé" >> $LOG_FILE
fi

# Archiver les anciens fichiers (plus de 7 jours)
ARCHIVE_DAYS=${ARCHIVE_DAYS:-7}
echo "Archivage des fichiers > $ARCHIVE_DAYS jours..."

find /truenas/downloads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null
find /truenas/uploads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null

echo "[$(date)] Archivage terminé" >> $LOG_FILE
echo "Synchronisation terminée!"
