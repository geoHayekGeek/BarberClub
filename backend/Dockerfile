# Build and run backend on Railway (or any Docker host)
FROM node:20-bookworm-slim AS base
WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install all deps (including dev) so we can run tsc
FROM base AS builder
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production image: only prod deps and built output
FROM base AS runner
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/prisma ./prisma
RUN npx prisma generate
COPY --from=builder /app/dist ./dist
EXPOSE 3000
# Apply migrations at startup (Railway Postgres starts empty)
# Optional: set RUN_SEED_ON_STARTUP=true to also seed default data
CMD ["sh", "-c", "npx prisma migrate deploy && if [ \"${RUN_SEED_ON_STARTUP:-false}\" = \"true\" ]; then node dist/prisma/seed.js; fi && node dist/src/server.js"]
