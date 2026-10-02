# syntax=docker/dockerfile:1
# Build context is the repo root: docker build -f apps/web/Dockerfile .

FROM node:22-slim AS base
RUN corepack enable
WORKDIR /repo

FROM base AS deps
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/web/package.json apps/web/package.json
COPY packages/schemas/package.json packages/schemas/package.json
COPY packages/api-types/package.json packages/api-types/package.json
RUN pnpm install --frozen-lockfile --filter web...

FROM deps AS build
COPY apps/web apps/web
COPY packages packages
RUN pnpm --filter web build

FROM nginx:1.27-alpine AS runtime
COPY --from=build /repo/apps/web/dist /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
