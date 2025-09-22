#!/bin/sh
set -e    # Stoppe le script en cas d'erreur

# Récupération de l'hôte et du port depuis les variables d'environnement
host="${DB_HOST:-db}"     # par défaut "db" si DB_HOST non défini
port="${DB_PORT:-5432}"   # par défaut 5432 si DB_PORT non défini
cmd="$@"                  # commande à exécuter après que la DB soit prête

echo "⏳ Attente de la base de données $host:$port..."

# Boucle tant que le port n'est pas ouvert
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
  echo "Postgres not ready yet - sleeping 2s"
  sleep 2
done

echo "✅ Base prête, lancement de l'application."

# Lance la commande passée en argument (ex : python manage.py runserver)
exec $cmd
