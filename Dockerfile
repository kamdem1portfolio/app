# ------------------------------
# Étape 1 : build frontend
# ------------------------------
FROM node:18 AS frontend

WORKDIR /frontend

# Copier les fichiers du frontend
# (ajuste le chemin selon la structure du repo,
# par exemple s’il y a un dossier frontend ou assets)
COPY static/ ./static/
COPY package*.json ./

# Installer les dépendances front
RUN npm install

# Construire le frontend (optimisé)
RUN npm run build

# ------------------------------
# Étape 2 : backend Django
# ------------------------------
FROM python:3.11-slim AS backend

WORKDIR /app

# Installer dépendances système nécessaires (par ex psycopg2, etc.)
RUN apt-get update 
RUN apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl netcat
RUN rm -rf /var/lib/apt/lists/*

# Copier requirements
COPY requirements.txt .

# Installer les paquets Python
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code Django
COPY . .

# Copier le build frontend dans les fichiers statiques Django
# (ajuste selon où Django attend les fichiers statiques)
COPY --from=frontend /frontend/build ./staticfiles/

# Script d’attente pour base de données
COPY wait-for-db.sh /wait-for-db.sh
RUN chmod +x /wait-for-db.sh

# Exposer le port sur lequel tourne Django
EXPOSE 8000

# Healthcheck (optionnel)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/healthz || exit 1

# Commande de démarrage : attend que la base soit prête, puis lance Django
CMD ["/wait-for-db.sh", "python", "manage.py", "runserver", "0.0.0.0:8000"]
