FROM node:22-alpine AS build

RUN apk add --no-cache python3 make g++
WORKDIR /app
COPY server/layer/package*.json ./
RUN npm ci
COPY server/layer/ ./
RUN npm run build

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/src/main.js"]
