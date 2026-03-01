# Keycloak on Railway

Deploy Keycloak 26 with a PostgreSQL database on [Railway](https://railway.app) using Docker, all configuration driven purely by environment variables.

---

## Architecture

```
Internet
   │  (HTTPS – Railway edge)
   ▼
Railway Service: keycloak   (port 8080, HTTP)
   │  (internal private network)
   ▼
Railway Service: PostgreSQL 16
```

---

## Quick Deploy

### 1. Fork / push this repo to GitHub (already done ✅)

### 2. Create a new Railway project

1. Go to [railway.app](https://railway.app) → **New Project**
2. Choose **Deploy from GitHub repo** → select `Muhammed2-h/keyclock`

### 3. Add a PostgreSQL plugin

Inside your Railway project:

1. Click **+ New** → **Database** → **Add PostgreSQL**
2. Railway automatically provisions the DB and exposes connection variables.

### 4. Set environment variables on the Keycloak service

In the Railway dashboard → your **keycloak** service → **Variables**, add:

| Variable                  | Value                                                                                                |
| ------------------------- | ---------------------------------------------------------------------------------------------------- |
| `KC_DB_URL`               | `jdbc:postgresql://${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}`               |
| `KC_DB_USERNAME`          | `${{Postgres.PGUSER}}`                                                                               |
| `KC_DB_PASSWORD`          | `${{Postgres.PGPASSWORD}}`                                                                           |
| `KC_HOSTNAME`             | _(Railway will set `RAILWAY_PUBLIC_DOMAIN` automatically; use `https://${{RAILWAY_PUBLIC_DOMAIN}}`)_ |
| `KEYCLOAK_ADMIN`          | `admin` _(or your preferred admin username)_                                                         |
| `KEYCLOAK_ADMIN_PASSWORD` | _(strong secret password)_                                                                           |
| `KC_HTTP_ENABLED`         | `true`                                                                                               |
| `KC_PROXY_HEADERS`        | `xforwarded`                                                                                         |
| `KC_HEALTH_ENABLED`       | `true`                                                                                               |
| `KC_METRICS_ENABLED`      | `true`                                                                                               |

> **Tip:** Railway lets you reference another service's variables with the `${{ServiceName.VAR}}` syntax. The PostgreSQL plugin service is usually named `Postgres`.

### 5. Deploy

Railway will build from the `Dockerfile` and deploy automatically. First boot takes ~60-90 seconds while Keycloak initialises the database schema.

### 6. Access Keycloak

Once healthy, visit your Railway public domain:

- **Admin Console** → `https://<your-domain>/admin`
- **Health check** → `https://<your-domain>/health/ready`

---

## Environment Variable Reference

| Variable                  | Description                          | Required          |
| ------------------------- | ------------------------------------ | ----------------- |
| `KC_DB`                   | DB vendor (`postgres`)               | Set in Dockerfile |
| `KC_DB_URL`               | Full JDBC URL                        | ✅                |
| `KC_DB_USERNAME`          | DB user                              | ✅                |
| `KC_DB_PASSWORD`          | DB password                          | ✅                |
| `KC_HOSTNAME`             | Public URL of your Keycloak instance | ✅                |
| `KEYCLOAK_ADMIN`          | Initial admin username               | ✅ (first boot)   |
| `KEYCLOAK_ADMIN_PASSWORD` | Initial admin password               | ✅ (first boot)   |
| `KC_HTTP_ENABLED`         | Enable plain HTTP listener           | `true`            |
| `KC_PROXY_HEADERS`        | Proxy header mode                    | `xforwarded`      |
| `KC_HEALTH_ENABLED`       | Enable `/health` endpoint            | `true`            |
| `KC_METRICS_ENABLED`      | Enable `/metrics` endpoint           | `true`            |

---

## Local Development

Run locally with Docker Compose:

```bash
# Create a .env file with at minimum:
# POSTGRES_PASSWORD=supersecret
# KEYCLOAK_ADMIN=admin
# KEYCLOAK_ADMIN_PASSWORD=admin

docker compose up --build
```

Keycloak will be available at `http://localhost:8080`.

---

## Notes

- The `Dockerfile` uses a **two-stage build**: the builder stage pre-compiles Keycloak for the `postgres` vendor (faster startup), and the runtime stage is lean.
- Railway terminates TLS at the edge so Keycloak only needs to listen on plain HTTP (`KC_HTTP_ENABLED=true`).
- `KC_PROXY_HEADERS=xforwarded` tells Keycloak to trust the `X-Forwarded-*` headers set by Railway's proxy, so HTTPS URLs are correctly reported to clients.
- `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` are only used on the **first boot** to create the master realm admin. You can remove them from Railway variables after the first successful deployment.
