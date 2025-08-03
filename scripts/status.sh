# ========================================
# scripts/status.sh
# ========================================
#!/bin/sh
echo "=== Statut du système FTP + TrueNAS ==="

echo "📊 SERVICES:"
echo "  TrueNAS: $(curl -s -f http://truenas > /dev/null && echo '✅ OK' || echo '❌ KO')"
echo "  FTP: $(timeout 5 lftp -e 'quit' -u $FTP_USER,$FTP_PASS $FTP_HOST > /dev/null 2>&1 && echo '✅ OK' || echo '❌ KO')"

echo ""
echo "💾 ESPACE DISQUE:"
df -h /truenas/* 2>/dev/null | grep -v Filesystem

echo ""
echo "📁 FICHIERS:"
echo "  Downloads: $(find /truenas/downloads -type f 2>/dev/null | wc -l) fichiers"
echo "  Uploads: $(find /truenas/uploads -type f 2>/dev/null | wc -l) fichiers"  
echo "  Archive: $(find /truenas/archive -type f 2>/dev/null | wc -l) fichiers"

echo ""
echo "📈 TAILLES:"
du -sh /truenas/* 2>/dev/null

echo ""
echo "📋 DERNIÈRES ACTIVITÉS:"
tail -5 /logs/downloads.log 2>/dev/null || echo "Aucun log de téléchargement"
