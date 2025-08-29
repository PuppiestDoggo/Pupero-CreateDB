# CreateDB now provides the MariaDB server image for the project
FROM mariadb:11

# The official mariadb image already handles initialization via environment
# variables and files placed in /docker-entrypoint-initdb.d
# We keep this image minimal and rely on docker-compose to pass env vars.

# Copy DB initialization scripts (run automatically on first launch when datadir is empty)
COPY DB/initdb.d/ /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh || true

# Expose default MariaDB port
EXPOSE 3306
