# ========================================
# scripts/download-to-truenas.sh
# ========================================
#!/bin/sh
# Usage: download-to-truenas.sh <fichier_distant> [dossier_local]

REMOTE_FILE=$1
LOCAL_DIR=${2:-/truenas/downloads}
LOG_FILE="/logs/downloads.log"

if [ -z "$REMOTE_FILE" ]; then
    echo "Usage: $0 <fichier_distant> [dossier_local]"
    exit 1
fi

echo "[$(date)] Début téléchargement: $REMOTE_FILE" >> $LOG_FILE

# Créer le dossier si nécessaire
mkdir -p $LOCAL_DIR

# Télécharger via FTP vers TrueNAS
lftp -u $FTP_USER,$FTP_PASS $FTP_HOST << EOF
set ftp:ssl-allow no
set ftp:passive-mode on
lcd $LOCAL_DIR
get $REMOTE_FILE
quit
EOF

if [ $? -eq 0 ]; then
    echo "[$(date)] ✅ Téléchargement réussi: $REMOTE_FILE → $LOCAL_DIR" >> $LOG_FILE
    echo "Fichier téléchargé avec succès dans TrueNAS: $LOCAL_DIR/$REMOTE_FILE"
    
    # Mettre à jour les permissions
    chmod 644 "$LOCAL_DIR/$REMOTE_FILE" 2>/dev/null
    
    # Log de la taille du fichier
    FILE_SIZE=$(ls -lh "$LOCAL_DIR/$REMOTE_FILE" 2>/dev/null | awk '{print $5}')
    echo "[$(date)] Taille: $FILE_SIZE" >> $LOG_FILE
else
    echo "[$(date)] ❌ Échec téléchargement: $REMOTE_FILE" >> $LOG_FILE
    echo "Erreur lors du téléchargement"
    exit 1
fi
