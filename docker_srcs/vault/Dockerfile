FROM hashicorp/vault:1.15

RUN apk add --no-cache curl \
    bash \
    net-tools \
    wget \
    openssl

COPY config.hcl /vault/config/config.hcl
COPY init-vault.sh /init-vault.sh

RUN chmod +x /init-vault.sh

EXPOSE 8200

ENTRYPOINT ["/init-vault.sh"]