# ── Stage 1: Dependencies ────────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

# ── Stage 2: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
RUN apk add --no-cache dos2unix
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Fix Windows CRLF → LF (git on Windows clones with CRLF)
RUN find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.json" -o -name "*.css" -o -name "*.scss" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) -exec dos2unix {} +

# Enable standalone output for minimal production bundle
RUN sed -i 's/const nextConfig = {/const nextConfig = { output: "standalone",/' next.config.js
RUN npm run build

# ── Stage 3: Production ─────────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3001

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy standalone server + static assets
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs
EXPOSE 3001

CMD ["node", "server.js"]
