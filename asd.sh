version: "3.8"

services:
  postgres:
    image: registry.viotech.local:5000/postgres:16-alpine
    container_name: keycloak-db
    restart: always
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-keycloak}
      POSTGRES_USER: ${POSTGRES_USER:-keycloak}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "-c max_connections=200 -c shared_buffers=256MB -c work_mem=4MB"
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - keycloak-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-keycloak}"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 512M

  keycloak:
    # ✅ Custom built image (pre-optimized for PostgreSQL)
    image: registry.viotech.local:5000/keycloak-prod:24.0.5
    container_name: keycloak
    restart: always
    # ✅ Production optimized command
    command: start --optimized
    ports:
      - "8080:8080"
    environment:
      # Admin
      KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN:-admin}
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}

      # Database (auto-detected from build)
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB:-keycloak}
      KC_DB_USERNAME: ${POSTGRES_USER:-keycloak}
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD}
      KC_DB_POOL_INITIAL_SIZE: 10
      KC_DB_POOL_MAX_SIZE: 20

      # Production settings
      KC_PROXY: edge
      KC_HOSTNAME: ${KC_HOSTNAME:-localhost:8080}
      KC_HOSTNAME_STRICT: "false"
      KC_HOSTNAME_STRICT_HTTPS: "false"
      KC_HTTP_ENABLED: "true"


      # Logging
      KC_LOG_LEVEL: "INFO"
      KC_LOG_CONSOLE_OUTPUT: "json"

      # Metrics & Health (enabled in build)
      KC_METRICS_ENABLED: "true"
      KC_HEALTH_ENABLED: "true"

      # JVM tuning
      JAVA_OPTS: "-Xms1024m -Xmx2048m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"


    depends_on:
      postgres:
        condition: service_healthy

    networks:
      - keycloak-network

    healthcheck:
      test: ["CMD", "curl", "-f", "http://keycloak.safelink.viotech.local:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

    deploy:
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 1024M
  nginx:
    image: registry.viotech.local:5000/nginx:alpine
    ports:
        - "80:80"
    volumes:
        - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
        - keycloak
    networks:
        - keycloak-network
volumes:
  pgdata:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR:-./data/postgres}

networks:
  keycloak-network:
    driver: bridge