# ========================================
# scripts/list-ftp.sh
# ========================================
#!/bin/sh
echo "=== Liste des fichiers FTP ==="

lftp -u $FTP_USER,$FTP_PASS $FTP_HOST << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
ls -la
quit
EOF
