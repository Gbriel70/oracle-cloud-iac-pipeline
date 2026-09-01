FROM node:20.12.2-alpine3.19

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev --no-audit --no-fund; else npm install --omit=dev --no-audit --no-fund; fi

COPY . .

RUN addgroup -S app && adduser -S app -G app && chown -R app:app /app

EXPOSE 3000
USER app

CMD ["node", "server.js"]
