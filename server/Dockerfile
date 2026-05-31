FROM node:18-alpine

WORKDIR /app

# Install wget for health check
RUN apk add --no-cache wget

COPY package*.json ./
RUN npm install --production

COPY src ./src

RUN mkdir -p data logs

EXPOSE 3000

CMD ["node", "src/server.js"]
