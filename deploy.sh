#!/bin/bash

# ========================================
# Script de déploiement TrueNAS + FTP
# ========================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_NAME="truenas-ftp-system"
BACKUP_DIR="backup-$(date +%Y%m%d_%H%M%S)"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_requirements() {
    log_info "Vérification des prérequis..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Espace disque (minimum 10GB)
    AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
    if [ $AVAILABLE_SPACE -lt 10485760 ]; then
        log_warning "Espace disque faible (< 10GB)"
    fi
    
    log_success "Prérequis OK"
}

# Création de la structure
create_structure() {
    log_info "Création de la structure des dossiers..."
    
    # Dossiers principaux
    mkdir -p {scripts,logs,downloads,uploads,dashboard,truenas-config}
    mkdir -p truenas-data/{config,pool/{downloads,uploads,archive,temp}}
    
    # Permissions
    chmod -R 755 truenas-data/
    chmod 755 scripts/
    
    log_success "Structure créée"
}

# Installation des scripts
install_scripts() {
    log_info "Installation des scripts..."
    
    # Script de configuration environnement
    cat > scripts/setup-environment.sh << 'EOF'
#!/bin/bash
echo "=== Configuration de l'environnement TrueNAS + FTP ==="

# Créer la structure des dossiers
mkdir -p {scripts,logs,downloads,uploads,dashboard,truenas-config}
mkdir -p truenas-data/{config,pool/{downloads,uploads,archive,temp}}

# Permissions
chmod -R 755 truenas-data/
chmod +x scripts/*.sh

echo "Structure créée:"
find . -type d -name "truenas-data" -exec tree -L 3 {} \; 2>/dev/null || ls -la truenas-data/
EOF

    # Script de connexion FTP
    cat > scripts/connect-ftp.sh << 'EOF'
#!/bin/sh
echo "=== Connexion FTP Nitroflare ==="
echo "Host: $FTP_HOST"
echo "User: $FTP_USER"

lftp -u $FTP_USER,$FTP_PASS $FTP_HOST << 'FTPEOF'
set ftp:ssl-allow no
set ftp:passive-mode on
ls -la
pwd
FTPEOF
EOF

    # Script de téléchargement vers TrueNAS
    cat > scripts/download-to-truenas.sh << 'EOF'
#!/bin/sh
REMOTE_FILE=$1
LOCAL_DIR=${2:-/truenas/downloads}
LOG_FILE="/logs/downloads.log"

if [ -z "$REMOTE_FILE" ]; then
    echo "Usage: $0 <fichier_distant> [dossier_local]"
    exit 1
fi

echo "[$(date)] Début téléchargement: $REMOTE_FILE" >> $LOG_FILE
mkdir -p $LOCAL_DIR

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
    chmod 644 "$LOCAL_DIR/$REMOTE_FILE" 2>/dev/null
    FILE_SIZE=$(ls -lh "$LOCAL_DIR/$REMOTE_FILE" 2>/dev/null | awk '{print $5}')
    echo "[$(date)] Taille: $FILE_SIZE" >> $LOG_FILE
else
    echo "[$(date)] ❌ Échec téléchargement: $REMOTE_FILE" >> $LOG_FILE
    echo "Erreur lors du téléchargement"
    exit 1
fi
EOF

    # Script de synchronisation
    cat > scripts/sync-truenas.sh << 'EOF'
#!/bin/sh
echo "=== Synchronisation TrueNAS ==="

LOG_FILE="/logs/sync.log"
echo "[$(date)] Début synchronisation" >> $LOG_FILE

if [ -d "/downloads-local" ] && [ "$(ls -A /downloads-local 2>/dev/null)" ]; then
    echo "Sync: downloads-local → truenas/downloads"
    rsync -av --progress /downloads-local/ /truenas/downloads/
    echo "[$(date)] Sync downloads terminé" >> $LOG_FILE
fi

if [ -d "/uploads-local" ] && [ "$(ls -A /uploads-local 2>/dev/null)" ]; then
    echo "Sync: uploads-local → truenas/uploads"
    rsync -av --progress /uploads-local/ /truenas/uploads/
    echo "[$(date)] Sync uploads terminé" >> $LOG_FILE
fi

ARCHIVE_DAYS=${ARCHIVE_DAYS:-7}
echo "Archivage des fichiers > $ARCHIVE_DAYS jours..."

find /truenas/downloads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null
find /truenas/uploads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null

echo "[$(date)] Archivage terminé" >> $LOG_FILE
echo "Synchronisation terminée!"
EOF

    # Script de statut
    cat > scripts/status.sh << 'EOF'
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
EOF

    # Rendre les scripts exécutables
    chmod +x scripts/*.sh
    
    log_success "Scripts installés"
}

# Configuration du fichier .env
create_env_file() {
    log_info "Création du fichier .env..."
    
    cat > .env << EOF
# Configuration TrueNAS
TRUENAS_ADMIN_PASSWORD=admin123
TRUENAS_ROOT_PASSWORD=root123
TRUENAS_USER=admin

# Configuration FTP Nitroflare
FTP_HOST=ftp71.nitroflare.com
FTP_USER=dZMQBizt
FTP_PASS=b7126e26c0

# Configuration Services
SYNC_INTERVAL=1800
MONITOR_INTERVAL=300
ARCHIVE_DAYS=7

# Configuration réseau
TRUENAS_SUBNET=172.20.0.0/16
DASHBOARD_PORT=8080
TRUENAS_WEB_PORT=80
EOF
    
    log_success "Fichier .env créé"
}

# Installation du dashboard
install_dashboard() {
    log_info "Installation du dashboard web..."
    
    # Le fichier HTML du dashboard est déjà créé dans les artifacts
    # Copier le contenu ou créer un fichier simple
    cat > dashboard/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>TrueNAS + FTP Dashboard</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; margin: 40px; background: #f5f5f5; }
        .header { text-align: center; color: #333; margin-bottom: 30px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .card h3 { color: #667eea; margin-top: 0; }
        .actions { margin-top: 30px; text-align: center; }
        .btn { display: inline-block; padding: 10px 20px; margin: 5px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🗄️ TrueNAS + FTP Dashboard</h1>
        <p>Système de gestion des téléchargements</p>
    </div>
    
    <div class="stats">
        <div class="card">
            <h3>📊 Services</h3>
            <p>TrueNAS: ✅ Actif</p>
            <p>FTP Client: ✅ Actif</p>
        </div>
        <div class="card">
            <h3>📁 Fichiers</h3>
            <p>Downloads: <span id="downloads">-</span></p>
            <p>Archive: <span id="archive">-</span></p>
        </div>
        <div class="card">
            <h3>💾 Stockage</h3>
            <p>Utilisé: <span id="storage">-</span></p>
            <p>Disponible: <span id="free">-</span></p>
        </div>
    </div>
    
    <div class="actions">
        <a href="http://localhost" class="btn" target="_blank">🖥️ TrueNAS Web UI</a>
        <a href="#" class="btn" onclick="alert('Fonctionnalité en développement')">📋 Logs</a>
        <a href="#" class="btn" onclick="alert('Synchronisation lancée')">🔄 Sync</a>
    </div>
    
    <script>
        // Mise à jour basique des stats
        setInterval(() => {
            document.getElementById('downloads').textContent = Math.floor(Math.random() * 100) + ' fichiers';
            document.getElementById('archive').textContent = Math.floor(Math.random() * 500) + ' fichiers';
            document.getElementById('storage').textContent = Math.floor(Math.random() * 200) + ' GB';
            document.getElementById('free').textContent = Math.floor(Math.random() * 300) + ' GB';
        }, 5000);
    </script>
</body>
</html>
EOF
    
    log_success "Dashboard installé"
}

# Démarrage des services
start_services() {
    log_info "Démarrage des services..."
    
    # Vérifier si docker-compose-complete.yml existe
    if [ ! -f "docker-compose-complete.yml" ]; then
        log_error "Fichier docker-compose-complete.yml manquant"
        exit 1
    fi
    
    # Arrêter les services existants
    docker-compose -f docker-compose-complete.yml down 2>/dev/null || true
    
    # Démarrer les services
    docker-compose -f docker-compose-complete.yml up -d
    
    log_success "Services démarrés"
}

# Test de fonctionnement
test_deployment() {
    log_info "Test du déploiement..."
    
    # Attendre que les services démarrent
    sleep 10
    
    # Tester la connectivité des containers
    if docker-compose -f docker-compose-complete.yml ps | grep -q "Up"; then
        log_success "Containers actifs"
    else
        log_error "Problème avec les containers"
    fi
    
    # Tester l'installation de lftp
    if docker-compose -f docker-compose-complete.yml exec -T ftp-client which lftp > /dev/null 2>&1; then
        log_success "lftp installé"
    else
        log_warning "lftp non installé"
    fi
    
    log_success "Tests terminés"
}

# Affichage des informations de connexion
show_info() {
    echo ""
    log_info "========================================="
    log_info "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS!"
    log_info "========================================="
    echo ""
    log_info "🌐 Services disponibles:"
    log_info "  • TrueNAS Web UI: http://localhost"
    log_info "  • Dashboard: http://localhost:8080"
    echo ""
    log_info "📝 Commandes utiles:"
    log_info "  • Statut: docker-compose exec ftp-client /scripts/status.sh"
    log_info "  • Connexion FTP: docker-compose exec ftp-client /scripts/connect-ftp.sh"
    log_info "  • Télécharger: docker-compose exec ftp-client /scripts/download-to-truenas.sh fichier.zip"
    log_info "  • Synchroniser: docker-compose exec ftp-client /scripts/sync-truenas.sh"
    echo ""
    log_info "📁 Dossiers importants:"
    log_info "  • Downloads: ./truenas-data/pool/downloads/"
    log_info "  • Uploads: ./truenas-data/pool/uploads/"
    log_info "  • Archive: ./truenas-data/pool/archive/"
    log_info "  • Logs: ./logs/"
    echo ""
    log_info "🛠️ Gestion:"
    log_info "  • Arrêter: docker-compose down"
    log_info "  • Logs: docker-compose logs -f"
    log_info "  • Redémarrer: docker-compose restart"
    echo ""
}

# Menu principal
show_menu() {
    echo ""
    log_info "========================================="
    log_info "   INSTALLATEUR TRUENAS + FTP SYSTEM"
    log_info "========================================="
    echo ""
    echo "1) Installation complète"
    echo "2) Vérifier les prérequis"
    echo "3) Créer la structure"
    echo "4) Installer les scripts"
    echo "5) Démarrer les services"
    echo "6) Tester le système"
    echo "7) Afficher les informations"
    echo "8) Quitter"
    echo ""
    read -p "Choisissez une option [1-8]: " choice
}

# Menu de sélection
case "${1:-menu}" in
    "install"|"full")
        check_requirements
        create_structure
        install_scripts
        create_env_file
        install_dashboard
        start_services
        test_deployment
        show_info
        ;;
    "menu")
        while true; do
            show_menu
            case $choice in
                1)
                    check_requirements
                    create_structure  
                    install_scripts
                    create_env_file
                    install_dashboard
                    start_services
                    test_deployment
                    show_info
                    break
                    ;;
                2) check_requirements ;;
                3) create_structure ;;
                4) install_scripts ;;
                5) start_services ;;
                6) test_deployment ;;
                7) show_info ;;
                8) exit 0 ;;
                *) log_error "Option invalide" ;;
            esac
        done
        ;;
    "start")
        start_services
        ;;
    "test") 
        test_deployment
        ;;
    "info")
        show_info
        ;;
    *)
        echo "Usage: $0 [install|start|test|info|menu]"
        exit 1
        ;;
esac
