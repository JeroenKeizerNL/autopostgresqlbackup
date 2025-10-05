# ---------------------------------------------------------
# Stage 1: Builder
FROM debian:bullseye-slim AS builder

LABEL maintainer="jeroen.keizer@outlook.com"

# Install curl, gnupg, and CA certs first
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    git

# Add PostgreSQL signing key to a scoped keyring
RUN curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg

# Add the PostgreSQL repo using signed-by
RUN echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

# Install dependencies
RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    postgresql-client-17

# Clone the backup script ans make executable
RUN git clone https://github.com/k0lter/autopostgresqlbackup.git /opt/autopostgresqlbackup \
&& chmod +x /opt/autopostgresqlbackup/autopostgresqlbackup

# ---------------------------------------------------------
# Stage 2: Final runtime image
FROM debian:bullseye-slim

# Install dependencies
# Include MySQL client for MariaDB/MySQL backup support via autopostgresqlbackup
RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    bash \
    gnupg \
    gzip \
    openssl \
    tzdata \
    passwd \
    cron \
    default-mysql-client \
&& rm -rf /var/lib/apt/lists/*

# Create folders
RUN mkdir -p /etc/autodbbackup.d \
&& mkdir -p "/backup" \
&& mkdir -p /opt/autopostgresqlbackup

# Copy only what's needed
COPY --from=builder /usr/lib/postgresql /usr/lib/postgresql
COPY --from=builder /usr/share/postgresql-common /usr/share/postgresql-common
COPY --from=builder /usr/lib/x86_64-linux-gnu/libpq.so.5.18 /usr/lib/x86_64-linux-gnu/libpq.so.5.18
COPY --from=builder /usr/share/perl5/PgCommon.pm /usr/share/perl5/PgCommon.pm
COPY --from=builder /opt/autopostgresqlbackup/autopostgresqlbackup /opt/autopostgresqlbackup/autopostgresqlbackup

# Recreate symlinks
RUN ln -s /usr/share/postgresql-common/pg_wrapper /usr/bin/pg_dump \
 && ln -s /usr/share/postgresql-common/pg_wrapper /usr/bin/pg_dumpall \
 && ln -s /usr/share/postgresql-common/pg_wrapper /usr/bin/pg_restore \
 && ln -s /usr/share/postgresql-common/pg_wrapper /usr/bin/psql \
 && ln -s /usr/lib/x86_64-linux-gnu/libpq.so.5.18 /usr/lib/x86_64-linux-gnu/libpq.so.5

# Copy and set Docker entrypoint
COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=20s --retries=3 \
  CMD pidof cron || (echo "cron not running" && exit 1)
