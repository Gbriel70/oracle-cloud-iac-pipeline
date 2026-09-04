FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid 1000 appgroup && adduser --system --uid 1000 --gid 1000 appgroup
USER appuser

WORKDIR /app

COPY target/release/DevSecOps_Audit_Engine /app/devsecops-api

EXPOSE 3000

CMD ["/app/devsecops-api"]