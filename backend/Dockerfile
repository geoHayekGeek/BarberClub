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
# Bundle default images; if Railway volume mounts at /app/public/images, we copy into it when empty
COPY --from=builder /app/public/images ./default-images
EXPOSE 3000
# Populate /app/public/images from bundled defaults when empty (e.g. new volume or no volume)
# Mount a Railway volume at /app/public/images to persist images across deploys
# Then: apply migrations, optional seed, start server
CMD ["sh", "-c", "mkdir -p /app/public/images && ([ -z \"$(ls -A /app/public/images 2>/dev/null)\" ] && cp -rn /app/default-images/. /app/public/images/ || true) && npx prisma migrate deploy && if [ \"${RUN_SEED_ON_STARTUP:-false}\" = \"true\" ]; then node dist/prisma/seed.js; fi && node dist/src/server.js"]
