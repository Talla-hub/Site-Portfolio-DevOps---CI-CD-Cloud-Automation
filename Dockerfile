# Utilisez une image légère avec Nginx
FROM nginx:alpine

# Copiez les fichiers statiques
COPY site_Portfolio/index.html /usr/share/nginx/html

# Port exposé
EXPOSE 80