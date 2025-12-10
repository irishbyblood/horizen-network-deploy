#!/bin/bash

# Horizen Network Deployment Script
# This script deploys the Horizen Network infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Deployment Script ===${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${YELLOW}Please edit .env file with your configuration before proceeding${NC}"
        exit 1
    else
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Environment file exists${NC}"

# Validate required environment variables
echo -e "\n${YELLOW}Validating environment variables...${NC}"
source .env

required_vars=("DOMAIN" "POSTGRES_PASSWORD" "MONGO_PASSWORD" "REDIS_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: Required variable $var is not set${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Required environment variables set${NC}"

# Determine deployment mode
DEPLOY_MODE="${1:-production}"
COMPOSE_FILES="-f docker-compose.yml"

if [ "$DEPLOY_MODE" = "dev" ] || [ "$DEPLOY_MODE" = "development" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.dev.yml"
    echo -e "\n${YELLOW}Deploying in DEVELOPMENT mode${NC}"
elif [ "$DEPLOY_MODE" = "prod" ] || [ "$DEPLOY_MODE" = "production" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.prod.yml"
    echo -e "\n${YELLOW}Deploying in PRODUCTION mode${NC}"
else
    echo -e "${RED}Error: Invalid deployment mode. Use 'dev' or 'prod'${NC}"
    exit 1
fi

# Pull latest images
echo -e "\n${YELLOW}Pulling latest Docker images...${NC}"
docker-compose $COMPOSE_FILES pull

# Create necessary directories
echo -e "\n${YELLOW}Creating necessary directories...${NC}"
mkdir -p ssl backups logs

# Stop existing containers
echo -e "\n${YELLOW}Stopping existing containers...${NC}"
docker-compose $COMPOSE_FILES down

# Start services
echo -e "\n${YELLOW}Starting services...${NC}"
docker-compose $COMPOSE_FILES up -d

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Perform health checks
echo -e "\n${YELLOW}Performing health checks...${NC}"

# Check PostgreSQL
if docker-compose $COMPOSE_FILES exec -T postgres pg_isready -U ${POSTGRES_USER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
else
    echo -e "${RED}✗ PostgreSQL is not ready${NC}"
fi

# Check MongoDB
if docker-compose $COMPOSE_FILES exec -T mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MongoDB is ready${NC}"
else
    echo -e "${RED}✗ MongoDB is not ready${NC}"
fi

# Check Redis
if docker-compose $COMPOSE_FILES exec -T redis redis-cli -a ${REDIS_PASSWORD} ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis is ready${NC}"
else
    echo -e "${RED}✗ Redis is not ready${NC}"
fi

# Check Nginx
if docker-compose $COMPOSE_FILES exec -T nginx nginx -t > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
fi

# Display running services
echo -e "\n${YELLOW}Running services:${NC}"
docker-compose $COMPOSE_FILES ps

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\nAccess your services at:"
echo -e "  Main Website: http://${DOMAIN}"
echo -e "  Druid Console: http://druid.${DOMAIN} or http://${DOMAIN}/druid"
echo -e "  Geniess: http://geniess.${DOMAIN}"

if [ "$DEPLOY_MODE" = "dev" ] || [ "$DEPLOY_MODE" = "development" ]; then
    echo -e "\n${YELLOW}Development ports exposed:${NC}"
    echo -e "  Druid Router: http://localhost:8888"
    echo -e "  Druid Coordinator: http://localhost:8081"
    echo -e "  PostgreSQL: localhost:5432"
    echo -e "  MongoDB: localhost:27017"
    echo -e "  Redis: localhost:6379"
fi

echo -e "\n${YELLOW}Note: For SSL/HTTPS setup, run: ./scripts/ssl-setup.sh${NC}"
