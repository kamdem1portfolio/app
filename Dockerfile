# =========================
# Étape 1 : Build et tests
# =========================
FROM python:3.11-slim AS builder

WORKDIR /app

# Installer dépendances système pour build et PostgreSQL
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    netcat-traditional \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier et installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY . .

# Lancer les tests unitaires & d’intégration pendant le build
#RUN python manage.py test


# =========================
# Étape 2 : Image finale
# =========================
FROM python:3.11-slim AS final

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libpq-dev \
    netcat-traditional \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier uniquement ce qui est nécessaire depuis le builder
COPY --from=builder /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

# Script d’attente pour la DB
COPY <<EOF /wait-for-db.sh
#!/bin/sh
set -e    # Stoppe le script en cas d erreur

# Récupération de l'hôte et du port de la DB depuis les variables d'environnement
host="\${DB_HOST:-db}"     # par défaut db si DB_HOST non défini
port="\${DB_PORT:-5432}"   # par défaut 5432 si DB_PORT non défini
cmd="\$@"                  # commande à exécuter une fois la DB prête

echo "⏳ Attente de la base de données \$host:\$port..."
until nc -z \$host \$port; do
  echo "⏳ Base non prête, réessai dans 2s..."
  sleep 2
done

# Boucle tant que le port n'est pas ouvert (la DB n'est pas prête)
echo "✅ Base prête, lancement de l'application."

# Lance la commande passée en argument (ex : python manage.py runserver)
exec \$cmd
EOF
RUN chmod +x /wait-for-db.sh

# Exposer le port
EXPOSE 8000

# Healthcheck pour Kubernetes / Docker
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/healthz || exit 1

# Commande de démarrage avec attente de DB
CMD ["/wait-for-db.sh", "python", "manage.py", "runserver", "0.0.0.0:8000"]
