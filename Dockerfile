# Multi-stage: Flutter web build → Dart WebSocket server (serves static + /ws).
# Build from repo root: docker build -t sheriff .

FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /app
COPY sheriff_shared/ sheriff_shared/
COPY sheriff_game/ sheriff_game/

WORKDIR /app/sheriff_game
RUN flutter pub get && flutter build web --release

FROM dart:stable AS runtime

WORKDIR /app
COPY sheriff_shared/ sheriff_shared/
COPY sheriff_server/ sheriff_server/

WORKDIR /app/sheriff_server
RUN dart pub get

COPY --from=flutter-build /app/sheriff_game/build/web /app/web

ENV WEB_BUILD_DIR=/app/web
EXPOSE 8080

WORKDIR /app/sheriff_server
CMD ["dart", "run", "bin/server.dart"]
