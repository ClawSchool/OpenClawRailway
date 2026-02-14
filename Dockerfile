FROM node:22-bookworm

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gosu && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Install OpenClaw via the public install script (npm global package)
RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt

ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Install Go (after OpenClaw so install layer stays cached across Go version bumps)
ARG GO_VERSION=1.22.5
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Create fallback state directory (used when no /data volume is mounted)
RUN mkdir -p /root/.openclaw && chown node:node /root/.openclaw

# Copy entrypoint script (sets HOME and OPENCLAW_STATE_DIR at runtime to avoid Railway overrides)
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Entrypoint runs as root to fix volume permissions, then drops to the
# non-root 'node' user (uid 1000) via gosu before starting the app.
ENTRYPOINT ["docker-entrypoint.sh"]

# Start gateway server bound to all interfaces so container platforms
# (Railway, Fly, etc.) can reach the health-check endpoint.
# Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD for auth.
CMD ["openclaw", "gateway", "--allow-unconfigured", "--bind", "lan"]
