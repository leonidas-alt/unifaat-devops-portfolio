# ──────────────────────────────────────────────────────────────────────────────
# Stage 1 — deps: instala apenas dependências de produção
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Copia apenas os manifests para aproveitar o cache de camadas
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2 — builder: valida sintaxe (poderia compilar TypeScript/transpile aqui)
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Verifica sintaxe sem executar o servidor
RUN node --check server.js && echo "Syntax OK"

# ──────────────────────────────────────────────────────────────────────────────
# Stage 3 — production: imagem final enxuta
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS production

# Metadados da imagem (OCI labels)
LABEL org.opencontainers.image.title="technova-api" \
      org.opencontainers.image.description="TechNova API — aula-09 DevOps UniFAAT" \
      org.opencontainers.image.vendor="TechNova" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Copia node_modules do stage deps e código do stage builder
COPY --from=deps    /app/node_modules ./node_modules
COPY --from=builder /app/server.js    ./server.js
COPY --from=builder /app/package.json ./package.json

# Porta exposta
EXPOSE 3000

# Executa como usuário não-root (segurança)
USER node

# Health check nativo do Docker
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
