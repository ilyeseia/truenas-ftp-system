# ========================================
# scripts/monitor-daemon.sh
# ========================================
#!/bin/sh
echo "=== Démarrage du daemon de monitoring ==="

apk add --no-cache curl jq

LOG_FILE="/logs/monitor.log"

while true; do
    echo "[$(date)] === Monitoring TrueNAS ===" >> $LOG_FILE
    
    # Vérifier l'espace disque
    echo "=== Espace disque ===" >> $LOG_FILE
    df -h /truenas/* >> $LOG_FILE 2>/dev/null
    
    # Compter les fichiers
    echo "=== Statistiques fichiers ===" >> $LOG_FILE
    echo "Downloads: $(find /truenas/downloads -type f | wc -l) fichiers" >> $LOG_FILE
    echo "Uploads: $(find /truenas/uploads -type f | wc -l) fichiers" >> $LOG_FILE
    echo "Archive: $(find /truenas/archive -type f | wc -l) fichiers" >> $LOG_FILE
    
    # Taille totale
    echo "=== Tailles ===" >> $LOG_FILE
    du -sh /truenas/* >> $LOG_FILE 2>/dev/null
    
    # Test de connectivité TrueNAS
    if curl -s -f http://$TRUENAS_HOST > /dev/null; then
        echo "[$(date)] ✅ TrueNAS accessible" >> $LOG_FILE
    else
        echo "[$(date)] ❌ TrueNAS inaccessible" >> $LOG_FILE
    fi
    
    echo "=== Fin monitoring ===" >> $LOG_FILE
    sleep $MONITOR_INTERVAL
done
