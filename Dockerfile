FROM docker/compose:latest

WORKDIR /app

COPY docker-compose.yml .
COPY docker-compose.prod.yml .
COPY nginx ./nginx
COPY druid ./druid
COPY public ./public
COPY scripts ./scripts
COPY .env.production .env

CMD ["docker-compose", "-f", "docker-compose.yml", "-f", "docker-compose.prod.yml", "up"]