# ─────────────────────────────────────────────────────────────
# Stage 1 – Build / configure Keycloak
# Uses the official Keycloak image so we get the full kc.sh tooling
# ─────────────────────────────────────────────────────────────
FROM quay.io/keycloak/keycloak:26.1 AS builder

# Enable health and metrics endpoints
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Tell Keycloak which DB vendor to optimise for at build time
ENV KC_DB=postgres

# Run the build step – this pre-processes Keycloak for faster startup
RUN /opt/keycloak/bin/kc.sh build

# ─────────────────────────────────────────────────────────────
# Stage 2 – Minimal runtime image
# ─────────────────────────────────────────────────────────────
FROM quay.io/keycloak/keycloak:26.1

# Copy the pre-built Keycloak from the builder stage
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# ── Runtime environment variables ────────────────────────────
# Database
ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Proxy / HTTP
# Railway terminates TLS at the edge, so we run plain HTTP internally
ENV KC_HTTP_ENABLED=true
ENV KC_PROXY_HEADERS=xforwarded
# Keycloak 26+ uses KC_PROXY_HEADERS instead of KC_PROXY

# Expose the HTTP port Railway will route to
EXPOSE 8080

# ── Entrypoint ───────────────────────────────────────────────
# "start" uses the pre-built config from Stage 1.
# All remaining runtime variables (KC_DB_URL, KC_DB_USERNAME,
# KC_DB_PASSWORD, KC_HOSTNAME, KEYCLOAK_ADMIN,
# KEYCLOAK_ADMIN_PASSWORD) are injected by Railway at runtime.
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
