# ── Stage 1: build Flutter web from source ────────────────────────────────────
FROM debian:bookworm-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive

# System dependencies required by Flutter & its pub packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl file git unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter stable by cloning the official repo
RUN git clone --depth 1 --branch stable \
      https://github.com/flutter/flutter.git /usr/local/flutter

ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH"
ENV FLUTTER_SUPPRESS_ANALYTICS=true

# Warm up flutter tool and web SDK only (skip Android/Gradle completely)
RUN flutter doctor -v --no-version-check || true \
    && flutter config --no-analytics \
    && flutter precache --web --no-android --no-ios --no-linux --no-macos --no-windows --no-fuchsia

# ── Dependency layer (cached unless pubspec changes) ───────────────────────────
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# ── Source + build ─────────────────────────────────────────────────────────────
COPY . .
RUN flutter build web --release --pwa-strategy=none

# ── Stage 2: serve with nginx ──────────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
