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

# KC_HOSTNAME  → set in Railway as the bare domain, e.g. sweetauth.up.railway.app
#                (NO https:// prefix – Keycloak 26 rejects full URLs here)
# KC_DB_URL    → set in Railway
# KC_DB_USERNAME / KC_DB_PASSWORD → set in Railway
# KEYCLOAK_ADMIN / KEYCLOAK_ADMIN_PASSWORD → set in Railway

EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
# --optimized uses the pre-built config from Stage 1
CMD ["start", "--optimized"]
