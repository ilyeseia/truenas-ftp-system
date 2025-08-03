# ========================================
# scripts/sync-daemon.sh
# ========================================
#!/bin/sh
echo "=== Démarrage du daemon de synchronisation ==="

apk add --no-cache rsync

while true; do
    echo "[$(date)] Exécution de la synchronisation automatique..."
    /scripts/sync-truenas.sh
    
    echo "Prochaine synchronisation dans $SYNC_INTERVAL secondes..."
    sleep $SYNC_INTERVAL
done
