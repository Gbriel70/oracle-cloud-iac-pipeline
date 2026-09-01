FROM postgres:16.4-alpine

RUN apk add --no-cache \
    postgresql-contrib \
    curl

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY postgresql.conf /usr/local/share/postgresql/postgresql.conf.custom
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    echo "include '/usr/local/share/postgresql/postgresql.conf.custom'" >> /usr/share/postgresql/postgresql.conf.sample || true

EXPOSE 5432
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
