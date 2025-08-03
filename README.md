# 🗄️ TrueNAS + FTP System

Système complet de gestion des téléchargements FTP avec stockage TrueNAS intégré.

## 🚀 Installation rapide

```bash
# 1. Cloner ou télécharger les fichiers
wget https://raw.githubusercontent.com/your-repo/deploy.sh
chmod +x deploy.sh

# 2. Installation automatique
./deploy.sh install

# 3. Accéder aux services
# TrueNAS: http://localhost
# Dashboard: http://localhost:8080
```

## 📋 Prérequis

- **Docker** >= 20.0
- **Docker Compose** >= 1.27
- **Espace disque** >= 10 GB
- **RAM** >= 4 GB
- **Système** : Linux/macOS/Windows avec WSL2

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FTP Server    │────│  Docker Host    │────│    TrueNAS      │
│  Nitroflare     │    │   FTP Client    │    │   Core NAS      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   Dashboard     │
                       │  (Web UI)       │
                       └─────────────────┘
```

## 📁 Structure du projet

```
truenas-ftp-system/
├── docker-compose-complete.yml    # Configuration Docker
├── deploy.sh                      # Script d'installation
├── .env                          # Variables d'environnement
├── scripts/                      # Scripts d'automatisation
│   ├── connect-ftp.sh           # Connexion FTP
│   ├── download-to-truenas.sh   # Téléchargement vers TrueNAS
│   ├── sync-truenas.sh          # Synchronisation
│   ├── status.sh                # Statut du système
│   └── ...
├── dashboard/                    # Interface web
│   └── index.html
├── truenas-data/                 # Données TrueNAS
│   ├── config/                  # Configuration
│   └── pool/                    # Pool de stockage
│       ├── downloads/           # Fichiers téléchargés
│       ├── uploads/             # Fichiers à uploader
│       ├── archive/             # Archives
│       └── temp/                # Temporaires
├── logs/                        # Fichiers de logs
└── downloads/                   # Downloads locaux
```

## 🛠️ Services inclus

### 1. **TrueNAS Core**
- Interface web de gestion
- Stockage ZFS avec snapshots
- Partages NFS/SMB
- Monitoring système

### 2. **FTP Client**
- Connexion automatique à Nitroflare
- Téléchargement vers TrueNAS
- Interface ligne de commande

### 3. **Service de Synchronisation**
- Synchronisation automatique
- Archivage des anciens fichiers
- Nettoyage automatique

### 4. **Dashboard Web**
- Monitoring en temps réel
- Actions rapides
- Visualisation des logs

## 📖 Guide d'utilisation

### Démarrage

```bash
# Démarrer tous les services
docker-compose -f docker-compose-complete.yml up -d

# Démarrer avec monitoring
docker-compose -f docker-compose-complete.yml --profile monitoring up -d

# Démarrer avec dashboard
docker-compose -f docker-compose-complete.yml --profile dashboard up -d
```

### Connexion FTP

```bash
# Connexion interactive
docker-compose exec ftp-client /scripts/connect-ftp.sh

# Lister les fichiers FTP
docker-compose exec ftp-client lftp -u $FTP_USER,$FTP_PASS $FTP_HOST -e "ls; quit"
```

### Téléchargements

```bash
# Télécharger un fichier vers TrueNAS
docker-compose exec ftp-client /scripts/download-to-truenas.sh fichier.zip

# Télécharger vers un dossier spécifique
docker-compose exec ftp-client /scripts/download-to-truenas.sh fichier.zip /truenas/archive

# Téléchargement en lot (depuis une liste)
echo -e "fichier1.zip\nfichier2.rar\ndossier/fichier3.pdf" > download-list.txt
docker-compose exec ftp-client /scripts/batch-download.sh /workspace/download-list.txt
```

### Synchronisation

```bash
# Synchronisation manuelle
docker-compose exec ftp-client /scripts/sync-truenas.sh

# La synchronisation automatique s'exécute toutes les 30 minutes par défaut
```

### Monitoring

```bash
# Voir le statut complet
docker-compose exec ftp-client /scripts/status.sh

# Voir les logs en temps réel
docker-compose logs -f

# Voir les logs d'un service spécifique
docker-compose logs -f ftp-client
docker-compose logs -f sync-service
```

## 🔧 Configuration

### Variables d'environnement (.env)

```bash
# Configuration TrueNAS
TRUENAS_ADMIN_PASSWORD=votre_mot_de_passe
TRUENAS_ROOT_PASSWORD=root_password
TRUENAS_USER=admin

# Configuration FTP
FTP_HOST=ftp71.nitroflare.com
FTP_USER=votre_username
FTP_PASS=votre_password

# Configuration Services
SYNC_INTERVAL=1800          # Synchronisation toutes les 30 min
MONITOR_INTERVAL=300        # Monitoring toutes les 5 min
ARCHIVE_DAYS=7              # Archiver après 7 jours

# Ports
DASHBOARD_PORT=8080
TRUENAS_WEB_PORT=80
```

### Personnalisation des scripts

Les scripts dans `scripts/` peuvent être modifiés selon vos besoins :

- **connect-ftp.sh** : Modifier les paramètres de connexion FTP
- **download-to-truenas.sh** : Personnaliser la logique de téléchargement
- **sync-truenas.sh** : Ajuster la synchronisation
- **status.sh** : Ajouter des métriques personnalisées

## 📊 Interface Web

### Dashboard (http://localhost:8080)
- 📈 Statistiques en temps réel
- 🎮 Actions rapides
- 📜 Logs système
- 🔄 Actualisation automatique

### TrueNAS Web UI (http://localhost)
- 🗄️ Gestion du stockage
- 📊 Monitoring système
- 🔧 Configuration avancée
- 📸 Snapshots et sauvegardes

## 🚨 Commandes de maintenance

### Nettoyage

```bash
# Nettoyer les fichiers temporaires
docker-compose exec ftp-client /scripts/cleanup-truenas.sh

# Nettoyer les containers et volumes
docker-compose down -v
docker system prune -f
```

### Sauvegardes

```bash
# Créer une sauvegarde
docker-compose exec ftp-client /scripts/backup-truenas.sh

# Sauvegarder la configuration
tar -czf backup-config-$(date +%Y%m%d).tar.gz docker-compose-complete.yml .env scripts/

# Restaurer depuis une sauvegarde
tar -xzf backup-config-YYYYMMDD.tar.gz
```

### Dépannage

```bash
# Redémarrer un service
docker-compose restart ftp-client

# Reconstruire les containers
docker-compose build --no-cache

# Vérifier l'état des services
docker-compose ps
docker-compose top

# Accéder au shell d'un container
docker-compose exec ftp-client sh
docker-compose exec truenas bash
```

## 🔍 Résolution de problèmes

### Problèmes courants

#### 1. **Connexion FTP échoue**
```bash
# Vérifier les credentials
docker-compose exec ftp-client env | grep FTP

# Tester la connectivité
docker-compose exec ftp-client ping ftp71.nitroflare.com
docker-compose exec ftp-client telnet ftp71.nitroflare.com 21
```

#### 2. **TrueNAS inaccessible**
```bash
# Vérifier le container TrueNAS
docker-compose logs truenas

# Redémarrer TrueNAS
docker-compose restart truenas

# Vérifier les ports
netstat -tlnp | grep :80
```

#### 3. **Problèmes de stockage**
```bash
# Vérifier l'espace disque
df -h
docker system df

# Nettoyer l'espace
docker system prune -a
```

#### 4. **Permissions des fichiers**
```bash
# Corriger les permissions
sudo chown -R $(id -u):$(id -g) truenas-data/
chmod -R 755 truenas-data/
```

### Logs de débogage

```bash
# Activer le mode debug
export COMPOSE_LOG_LEVEL=DEBUG

# Logs détaillés
docker-compose -f docker-compose-complete.yml --verbose up

# Logs par service
docker-compose logs --tail=100 ftp-client
docker-compose logs --tail=100 sync-service
docker-compose logs --tail=100 truenas
```

## 📈 Optimisations

### Performance

```bash
# Optimiser Docker
echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

# Monitoring des ressources
docker stats
```

### Sécurité

```bash
# Changer les mots de passe par défaut
# Éditer le fichier .env avec des mots de passe forts

# Limiter l'accès réseau
# Configurer un firewall si nécessaire
```

### Automatisation

```bash
# Ajouter au crontab pour démarrage automatique
echo "@reboot cd /path/to/project && docker-compose up -d" | crontab -

# Script de surveillance
#!/bin/bash
# health-check.sh
if ! docker-compose ps | grep -q "Up"; then
    docker-compose up -d
    echo "Services redémarrés: $(date)" >> /var/log/truenas-ftp.log
fi
```

## 🤝 Contribution

### Structure de développement

```bash
# Mode développement
docker-compose -f docker-compose-complete.yml --profile dev up -d

# Tests
./deploy.sh test

# Ajout de nouvelles fonctionnalités
# 1. Modifier les scripts dans scripts/
# 2. Tester avec le container dev-tools
# 3. Mettre à jour la documentation
```

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 🆘 Support

### Documentation officielle
- [Docker](https://docs.docker.com)
- [Docker Compose](https://docs.docker.com/compose)
- [TrueNAS](https://www.truenas.com/docs)

### Communauté
- Issues GitHub
- Forums TrueNAS
- Discord Docker

## 🚀 Roadmap

### Version actuelle (1.0)
- ✅ Installation automatique
- ✅ Interface web dashboard
- ✅ Synchronisation automatique
- ✅ Monitoring de base

### Version future (2.0)
- 🔄 API REST
- 📱 Application mobile
- 🔒 Authentification avancée
- 📊 Métriques avancées
- 🌐 Support multi-serveurs FTP
- 🤖 Intelligence artificielle pour l'optimisation

---

## 📞 Contact

Pour toute question ou suggestion :
- 📧 Email : keskasilyes@gmail.com


---

**Fait avec ❤️ pour la communauté open source**
