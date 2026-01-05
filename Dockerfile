# Serve pre-built Flutter web files
FROM nginx:alpine

# Copy pre-built web files (must be built locally with: flutter build web --release)
COPY build/web /usr/share/nginx/html

# Copy custom nginx config for SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
