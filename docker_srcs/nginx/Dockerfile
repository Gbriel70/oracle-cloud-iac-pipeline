FROM owasp/modsecurity-crs:3.3-nginx-alpine

RUN apk add --no-cache ca-certificates tzdata && \
    mkdir -p /var/cache/nginx /var/run /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /etc/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d
RUN mkdir -p /etc/nginx/templates/conf.d && \
    cp /etc/nginx/conf.d/default.conf /etc/nginx/templates/conf.d/default.conf.template
COPY entrypoint.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh && \
    chown nginx:nginx /docker-entrypoint-custom.sh

EXPOSE 80
USER nginx
ENTRYPOINT ["/docker-entrypoint-custom.sh"]
CMD ["nginx", "-g", "daemon off;"]
