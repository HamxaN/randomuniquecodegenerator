# ClipCraft server: holds the Claude key for the app. Build from the clipcraft folder:
#   docker build -f server/Dockerfile -t clipcraft-server .
#   docker run -d -p 8080:8080 -e ANTHROPIC_API_KEY=... -e APP_TOKEN=... clipcraft-server
FROM gradle:8.14.3-jdk17 AS build
WORKDIR /src
COPY gradle ./gradle
COPY core ./core
COPY server ./server
RUN gradle -p server installDist --no-daemon -q

FROM eclipse-temurin:17-jre
COPY --from=build /src/server/build/install/clipcraft-server /app
EXPOSE 8080
ENV PORT=8080
CMD ["/app/bin/clipcraft-server"]
