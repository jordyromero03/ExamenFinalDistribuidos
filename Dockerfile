# etapa 1 build instancias y dependecias y se corre las pruebas del fail test

FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run test

# etapa 2 imagen final minima, solo lo necesario para ejecutar

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev && rm -rf /usr/local/lib/node_modules/npm

COPY --from=build /app/server.js ./server.js
COPY --from=build /app/db.js ./db.js
COPY --from=build /app/public ./public

RUN mkdir -p /app/data && chown -R node:node /app
USER node

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]