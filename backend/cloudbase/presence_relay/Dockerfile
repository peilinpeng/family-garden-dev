FROM node:20-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY server.js ./

ENV PORT=8080
EXPOSE 8080
CMD ["npm", "start"]
