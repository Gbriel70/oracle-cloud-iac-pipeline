FROM rust:alpine AS chef
RUN apk add --no-cache musl-dev gcc
RUN cargo install cargo-chef --locked
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

COPY . .
RUN cargo build --release --bin DevSecOps_Audit_Engine

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

RUN addgroup -g 1000 -S appgroup && adduser -u 1000 -S appuser -G appgroup
USER appuser

WORKDIR /app
COPY --from=builder /app/target/release/DevSecOps_Audit_Engine /app/devsecops-api

EXPOSE 3000

CMD ["/app/devsecops-api"]