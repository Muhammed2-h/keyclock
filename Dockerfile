# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – Build / configure Keycloak
# Build-time options MUST be set here when using --optimized at runtime.
# ─────────────────────────────────────────────────────────────────────────────
FROM quay.io/keycloak/keycloak:26.1 AS builder

# ── Build-time options (baked into the optimised binary) ──────────────────────
ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
# Railway terminates TLS at the edge → Keycloak runs plain HTTP internally
ENV KC_HTTP_ENABLED=true
# Trust X-Forwarded-* headers set by Railway's edge proxy
ENV KC_PROXY_HEADERS=xforwarded
# Enable HTTP/2 for multiplexed, faster connections
ENV KC_HTTP_RELATIVE_PATH=/
# Optimise DB connection pool at build time
ENV KC_DB_POOL_INITIAL_SIZE=5
ENV KC_DB_POOL_MIN_SIZE=5
ENV KC_DB_POOL_MAX_SIZE=15

# Pre-compile Keycloak with the above settings for fast startup
RUN /opt/keycloak/bin/kc.sh build

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – Lean runtime image
# ─────────────────────────────────────────────────────────────────────────────
FROM quay.io/keycloak/keycloak:26.1

COPY --from=builder /opt/keycloak/ /opt/keycloak/

# ── Runtime defaults (can be overridden by Railway env vars) ──────────────────
ENV KC_DB=postgres
ENV KC_HTTP_ENABLED=true
ENV KC_PROXY_HEADERS=xforwarded
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# ── Performance tuning ────────────────────────────────────────────────────────
# Only log warnings/errors – reduces I/O and speeds up response times
ENV KC_LOG_LEVEL=WARN
# DB connection pool – pre-warm connections to avoid cold-connection latency
ENV KC_DB_POOL_INITIAL_SIZE=5
ENV KC_DB_POOL_MIN_SIZE=5
ENV KC_DB_POOL_MAX_SIZE=15
# Cache: use local (in-process) caches for single-instance Railway deploy
ENV KC_CACHE=local
# JVM: explicit heap sizing prevents JVM under-allocating in containers
# Adjust based on your Railway plan memory (below = ~512 MB plan safe)
ENV JAVA_OPTS_APPEND="-Xms256m -Xmx384m -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+UseStringDeduplication -Djava.net.preferIPv4Stack=true"

# KC_HOSTNAME  → set in Railway as the bare domain, e.g. sweetauth.up.railway.app
#                (NO https:// prefix – Keycloak 26 rejects full URLs here)
# KC_DB_URL    → set in Railway
# KC_DB_USERNAME / KC_DB_PASSWORD → set in Railway
# KEYCLOAK_ADMIN / KEYCLOAK_ADMIN_PASSWORD → set in Railway

EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
# --optimized uses the pre-built config from Stage 1
CMD ["start", "--optimized"]
