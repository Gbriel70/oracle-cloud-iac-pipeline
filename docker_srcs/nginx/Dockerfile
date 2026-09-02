FROM owasp/modsecurity-crs:3.3-nginx-alpine

RUN apk add --no-cache ca-certificates tzdata && \
    mkdir -p /var/cache/nginx /var/run /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /etc/nginx

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080
USER nginx
ENTRYPOINT ["nginx", "-g", "daemon off;"]
