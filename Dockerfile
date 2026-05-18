# Build Flutter web app from source
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Cache pub dependencies first for faster rebuilds
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy source and build web release
COPY . .
RUN flutter config --enable-web && flutter build web --release

# Serve built web app with nginx
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
