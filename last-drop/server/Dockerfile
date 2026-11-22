# Dedicated Last Drop server. Build from the last-drop folder:
#   docker build -f server/Dockerfile -t last-drop-server .
#   docker run -d -p 7777:7777/udp last-drop-server
FROM ubuntu:24.04
ARG GODOT_VERSION=4.6.3
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
RUN curl -sSfL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /opt \
 && mv "/opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm /tmp/godot.zip
COPY . /game
WORKDIR /game
# Import once at build time so the server starts quickly.
RUN godot --headless --path /game --import > /dev/null 2>&1 || true \
 && godot --headless --path /game --import > /dev/null 2>&1 || true
EXPOSE 7777/udp
ENV MODE=squad
CMD ["sh", "-c", "exec stdbuf -oL godot --headless --path /game -- --server --port=7777 --mode=${MODE}"]
