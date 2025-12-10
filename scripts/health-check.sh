#!/bin/bash

# Horizen Network Health Check Script
# Verifies all services are running properly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Health Check ===${NC}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

ERRORS=0

# Check Docker containers
echo -e "\n${YELLOW}Checking Docker containers...${NC}"

CONTAINERS=("horizen-nginx" "horizen-zookeeper" "horizen-postgres" "horizen-mongodb" "horizen-redis" "horizen-druid-coordinator" "horizen-druid-broker" "horizen-druid-router" "horizen-druid-historical" "horizen-druid-middlemanager")

for container in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "$container")
        if [ "$STATUS" = "running" ]; then
            echo -e "${GREEN}✓ $container is running${NC}"
        else
            echo -e "${RED}✗ $container is not running (Status: $STATUS)${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${RED}✗ $container not found${NC}"
        ((ERRORS++))
    fi
done

# Check Nginx
echo -e "\n${YELLOW}Checking Nginx...${NC}"
if curl -f -s http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx is responding${NC}"
else
    echo -e "${RED}✗ Nginx is not responding${NC}"
    ((ERRORS++))
fi

# Check Nginx configuration
if docker exec horizen-nginx nginx -t > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    ((ERRORS++))
fi

# Check PostgreSQL
echo -e "\n${YELLOW}Checking PostgreSQL...${NC}"
if docker exec horizen-postgres pg_isready -U ${POSTGRES_USER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
    
    # Check connection
    if docker exec horizen-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL connection successful${NC}"
    else
        echo -e "${RED}✗ PostgreSQL connection failed${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ PostgreSQL is not ready${NC}"
    ((ERRORS++))
fi

# Check MongoDB
echo -e "\n${YELLOW}Checking MongoDB...${NC}"
if docker exec horizen-mongodb mongosh --quiet --eval "db.adminCommand('ping').ok" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MongoDB is responding${NC}"
else
    echo -e "${RED}✗ MongoDB is not responding${NC}"
    ((ERRORS++))
fi

# Check Redis
echo -e "\n${YELLOW}Checking Redis...${NC}"
if docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✓ Redis is responding${NC}"
else
    echo -e "${RED}✗ Redis is not responding${NC}"
    ((ERRORS++))
fi

# Check ZooKeeper
echo -e "\n${YELLOW}Checking ZooKeeper...${NC}"
if docker exec horizen-zookeeper zkServer.sh status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ZooKeeper is running${NC}"
else
    echo -e "${RED}✗ ZooKeeper is not running${NC}"
    ((ERRORS++))
fi

# Check Druid Router Console
echo -e "\n${YELLOW}Checking Druid Router...${NC}"
if curl -f -s http://localhost:8888/status > /dev/null 2>&1 || docker exec horizen-druid-router curl -f -s http://localhost:8888/status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Druid Router is accessible${NC}"
else
    echo -e "${YELLOW}! Druid Router may still be starting up${NC}"
fi

# Check Druid Coordinator
echo -e "\n${YELLOW}Checking Druid Coordinator...${NC}"
if docker exec horizen-druid-coordinator curl -f -s http://localhost:8081/status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Druid Coordinator is accessible${NC}"
else
    echo -e "${YELLOW}! Druid Coordinator may still be starting up${NC}"
fi

# Check Druid Broker
echo -e "\n${YELLOW}Checking Druid Broker...${NC}"
if docker exec horizen-druid-broker curl -f -s http://localhost:8082/status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Druid Broker is accessible${NC}"
else
    echo -e "${YELLOW}! Druid Broker may still be starting up${NC}"
fi

# Check disk space
echo -e "\n${YELLOW}Checking disk space...${NC}"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓ Disk space OK ($DISK_USAGE% used)${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}! Disk space warning ($DISK_USAGE% used)${NC}"
else
    echo -e "${RED}✗ Disk space critical ($DISK_USAGE% used)${NC}"
    ((ERRORS++))
fi

# Check memory usage
echo -e "\n${YELLOW}Checking memory usage...${NC}"
MEMORY_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ "$MEMORY_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓ Memory usage OK ($MEMORY_USAGE% used)${NC}"
elif [ "$MEMORY_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}! Memory usage warning ($MEMORY_USAGE% used)${NC}"
else
    echo -e "${RED}✗ Memory usage critical ($MEMORY_USAGE% used)${NC}"
    ((ERRORS++))
fi

# Summary
echo -e "\n${GREEN}=== Health Check Complete ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Found $ERRORS error(s)${NC}"
    exit 1
fi
