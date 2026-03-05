# 🔐 Vaultwarden VM Install Script

Script d'installation automatisé de [Vaultwarden](https://github.com/dani-garcia/vaultwarden) 
sur une VM Debian 12 / Ubuntu 24.04 (idéal Proxmox).

## 📦 Ce que le script installe
- Docker & Docker Compose
- Vaultwarden (dernière version)
- Nginx en reverse proxy
- Certificat SSL auto-signé
- Token admin hashé (Argon2)

## ⚙️ Prérequis
- VM Debian 12 ou Ubuntu 24.04
- 2 vCPU / 2 GB RAM / 16 GB disque
- Accès sudo

## 🚀 Installation

\`\`\`bash
# 1. Cloner le repo
git clone https://github.com/TON_USER/vaultwarden-vm-install.git
cd vaultwarden-vm-install

# 2. Modifier les variables (domaine, mot de passe admin)
nano install-vaultwarden.sh

# 3. Lancer
sudo bash install-vaultwarden.sh
\`\`\`

## 🔧 Variables à configurer

| Variable | Description | Défaut |
|----------|-------------|--------|
| `DOMAIN` | Ton domaine ou IP locale | `vault.mondomaine.local` |
| `ADMIN_PASS` | Mot de passe panneau admin | `ChangeMoi123!` |
| `DATA_DIR` | Répertoire des données | `/opt/vaultwarden` |

## 📋 Après l'installation

- Interface : `https://DOMAIN`
- Panneau admin : `https://DOMAIN/admin`
- Données : `/opt/vaultwarden/data`
- Mise à jour : `cd /opt/vaultwarden && docker compose pull && docker compose up -d`

## 📄 Licence
GPL-3.0 — cohérent avec la licence de Vaultwarden lui-même.
