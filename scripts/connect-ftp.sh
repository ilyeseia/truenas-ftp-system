# ========================================
# scripts/connect-ftp.sh
# ========================================
#!/bin/sh
echo "=== Connexion FTP Nitroflare ==="
echo "Host: $FTP_HOST"
echo "User: $FTP_USER"

lftp -u $FTP_USER,$FTP_PASS $FTP_HOST << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
ls -la
pwd
EOF
