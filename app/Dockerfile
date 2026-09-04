FROM rust:bookworm

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

WORKDIR /app/DevSecOps_Audit_Engine

EXPOSE 3000

CMD ["cargo", "run", "--release", "--bin", "DevSecOps_Audit_Engine"]