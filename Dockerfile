# Build stage
FROM cirrusci/flutter:stable AS build
WORKDIR /app

# Copy project files
COPY pubspec.* ./
RUN flutter pub get
COPY . .

# Build web
RUN flutter build web --release

# Serve stage
FROM nginx:alpine

# Copy compiled web output
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
