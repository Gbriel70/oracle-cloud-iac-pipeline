FROM hashicorp/vault:1.15.6

RUN apk add --no-cache curl bash net-tools wget openssl && \
    mkdir -p /vault/config /vault/tokens && \
    chown -R vault:vault /vault

COPY config.hcl /vault/config/config.hcl
COPY init-vault.sh /init-vault.sh
RUN chmod +x /init-vault.sh && chown vault:vault /init-vault.sh /vault/config/config.hcl

EXPOSE 8200
USER vault
ENTRYPOINT ["/init-vault.sh"]