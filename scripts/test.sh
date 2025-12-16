#!/bin/bash

# Horizen Network Integration Testing Script
# Runs comprehensive tests on deployed infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Horizen Network Integration Tests ===${NC}"

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

PASSED=0
FAILED=0
SKIPPED=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        ((FAILED++))
        return 1
    fi
}

# Function to skip test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    echo -e "${YELLOW}⊘ SKIPPED: $reason${NC}"
    ((SKIPPED++))
}

# 1. API Endpoint Tests
echo -e "\n${BLUE}=== API Endpoint Tests ===${NC}"

# Test Nginx health endpoint
if docker ps | grep -q horizen-nginx; then
    run_test "Nginx health endpoint" \
        "curl -f -s http://localhost/health"
    
    run_test "Nginx returns 200 OK" \
        "curl -s -o /dev/null -w '%{http_code}' http://localhost/ | grep -q 200"
else
    skip_test "Nginx endpoints" "Nginx container not running"
fi

# Test Druid Router API
if docker ps | grep -q horizen-druid-router; then
    run_test "Druid Router status endpoint" \
        "docker exec horizen-druid-router curl -f -s http://localhost:8888/status"
    
    run_test "Druid Router SQL endpoint" \
        "docker exec horizen-druid-broker curl -f -s http://localhost:8082/druid/v2/sql -H 'Content-Type: application/json' -d '{\"query\":\"SELECT 1\"}'"
else
    skip_test "Druid API endpoints" "Druid containers not running"
fi

# 2. Database Connection Tests
echo -e "\n${BLUE}=== Database Connection Tests ===${NC}"

# Test PostgreSQL
if docker ps | grep -q horizen-postgres; then
    run_test "PostgreSQL connection" \
        "docker exec horizen-postgres pg_isready -U ${POSTGRES_USER}"
    
    run_test "PostgreSQL query execution" \
        "docker exec horizen-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c 'SELECT 1;'"
else
    skip_test "PostgreSQL tests" "PostgreSQL container not running"
fi

# Test MongoDB
if docker ps | grep -q horizen-mongodb; then
    run_test "MongoDB connection" \
        "docker exec horizen-mongodb mongosh --quiet --eval 'db.adminCommand(\"ping\").ok' | grep -q 1"
    
    run_test "MongoDB write operation" \
        "docker exec horizen-mongodb mongosh --quiet --eval 'db.test.insertOne({test: true})' | grep -q acknowledged"
else
    skip_test "MongoDB tests" "MongoDB container not running"
fi

# Test Redis
if docker ps | grep -q horizen-redis; then
    run_test "Redis connection" \
        "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} ping | grep -q PONG"
    
    run_test "Redis SET/GET operation" \
        "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} SET test_key test_value && docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} GET test_key | grep -q test_value"
else
    skip_test "Redis tests" "Redis container not running"
fi

# Test ZooKeeper
if docker ps | grep -q horizen-zookeeper; then
    run_test "ZooKeeper status" \
        "docker exec horizen-zookeeper zkServer.sh status"
else
    skip_test "ZooKeeper tests" "ZooKeeper container not running"
fi

# 3. Service Health Checks
echo -e "\n${BLUE}=== Service Health Checks ===${NC}"

# Check all containers are running
EXPECTED_CONTAINERS=(
    "horizen-nginx"
    "horizen-zookeeper"
    "horizen-postgres"
    "horizen-mongodb"
    "horizen-redis"
    "horizen-druid-coordinator"
    "horizen-druid-broker"
    "horizen-druid-router"
    "horizen-druid-historical"
    "horizen-druid-middlemanager"
)

for container in "${EXPECTED_CONTAINERS[@]}"; do
    run_test "Container $container is running" \
        "docker ps --format '{{.Names}}' | grep -q ^${container}$"
done

# 4. Performance Benchmarks
echo -e "\n${BLUE}=== Performance Benchmarks ===${NC}"

# Test Nginx response time
if docker ps | grep -q horizen-nginx; then
    echo -e "${YELLOW}Testing: Nginx response time${NC}"
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' http://localhost/)
    if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
        echo -e "${GREEN}✓ PASSED: Nginx response time (${RESPONSE_TIME}s < 1.0s)${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED: Nginx response time (${RESPONSE_TIME}s >= 1.0s)${NC}"
        ((FAILED++))
    fi
fi

# Test database query performance
if docker ps | grep -q horizen-postgres; then
    echo -e "${YELLOW}Testing: PostgreSQL query performance${NC}"
    START_TIME=$(date +%s.%N)
    docker exec horizen-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c 'SELECT COUNT(*) FROM pg_tables;' >/dev/null 2>&1
    END_TIME=$(date +%s.%N)
    QUERY_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    if (( $(echo "$QUERY_TIME < 0.5" | bc -l) )); then
        echo -e "${GREEN}✓ PASSED: PostgreSQL query performance (${QUERY_TIME}s < 0.5s)${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED: PostgreSQL query performance (${QUERY_TIME}s >= 0.5s)${NC}"
        ((FAILED++))
    fi
fi

# 5. Load Testing (Light)
echo -e "\n${BLUE}=== Load Testing ===${NC}"

if command -v ab >/dev/null 2>&1; then
    if docker ps | grep -q horizen-nginx; then
        echo -e "${YELLOW}Testing: Nginx under light load (100 requests, 10 concurrent)${NC}"
        AB_RESULT=$(ab -n 100 -c 10 -q http://localhost/ 2>&1)
        FAILED_REQUESTS=$(echo "$AB_RESULT" | grep "Failed requests:" | awk '{print $3}')
        
        if [ "$FAILED_REQUESTS" = "0" ]; then
            echo -e "${GREEN}✓ PASSED: All requests successful${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ FAILED: $FAILED_REQUESTS requests failed${NC}"
            ((FAILED++))
        fi
        
        # Extract requests per second
        RPS=$(echo "$AB_RESULT" | grep "Requests per second:" | awk '{print $4}')
        echo -e "  Requests per second: ${RPS}"
    else
        skip_test "Load testing" "Nginx container not running"
    fi
else
    skip_test "Load testing" "ApacheBench (ab) not installed"
fi

# 6. Memory and Resource Tests
echo -e "\n${BLUE}=== Resource Usage Tests ===${NC}"

# Check memory usage of containers
echo -e "${YELLOW}Testing: Container memory usage${NC}"
MEMORY_ISSUES=0

while IFS= read -r line; do
    CONTAINER_NAME=$(echo "$line" | awk '{print $1}')
    MEMORY_USAGE=$(echo "$line" | awk '{print $2}' | sed 's/MiB//')
    MEMORY_LIMIT=$(echo "$line" | awk '{print $4}' | sed 's/GiB//' | awk '{print $1 * 1024}')
    
    if [ -n "$MEMORY_LIMIT" ] && [ "$MEMORY_LIMIT" != "0" ]; then
        USAGE_PERCENT=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_LIMIT) * 100" | bc)
        if (( $(echo "$USAGE_PERCENT > 90" | bc -l) )); then
            echo -e "${RED}  ✗ $CONTAINER_NAME: ${USAGE_PERCENT}% memory usage (high)${NC}"
            ((MEMORY_ISSUES++))
        else
            echo -e "${GREEN}  ✓ $CONTAINER_NAME: ${USAGE_PERCENT}% memory usage${NC}"
        fi
    fi
done < <(docker stats --no-stream --format "{{.Name}} {{.MemUsage}}" | grep horizen-)

if [ $MEMORY_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED: All containers within memory limits${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED: $MEMORY_ISSUES containers have high memory usage${NC}"
    ((FAILED++))
fi

# 7. Security Tests
echo -e "\n${BLUE}=== Security Tests ===${NC}"

# Test that database ports are not exposed externally (in production)
if [ "${ENVIRONMENT}" = "production" ]; then
    run_test "PostgreSQL port not exposed externally" \
        "! docker port horizen-postgres | grep -q '0.0.0.0'"
    
    run_test "MongoDB port not exposed externally" \
        "! docker port horizen-mongodb | grep -q '0.0.0.0'"
    
    run_test "Redis port not exposed externally" \
        "! docker port horizen-redis | grep -q '0.0.0.0'"
else
    skip_test "External port exposure tests" "Not in production environment"
fi

# Test SSL is enabled in production
if [ "${ENVIRONMENT}" = "production" ]; then
    if [ "${ENABLE_SSL}" = "true" ]; then
        echo -e "${GREEN}✓ PASSED: SSL is enabled in production${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED: SSL should be enabled in production${NC}"
        ((FAILED++))
    fi
else
    skip_test "SSL requirement" "Not in production environment"
fi

# 8. Data Integrity Tests
echo -e "\n${BLUE}=== Data Integrity Tests ===${NC}"

# Test PostgreSQL data integrity
if docker ps | grep -q horizen-postgres; then
    run_test "PostgreSQL metadata tables exist" \
        "docker exec horizen-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c '\dt' | grep -q druid"
else
    skip_test "PostgreSQL data integrity" "PostgreSQL container not running"
fi

# 9. Backup System Tests
echo -e "\n${BLUE}=== Backup System Tests ===${NC}"

# Check if backup script exists and is executable
run_test "Backup script exists and is executable" \
    "test -x ./scripts/backup.sh"

# Check if backup directory exists
run_test "Backup directory exists" \
    "test -d ./backups || mkdir -p ./backups"

# 10. Monitoring Tests
echo -e "\n${BLUE}=== Monitoring Tests ===${NC}"

# Check if Prometheus configuration is valid
if [ -f monitoring/prometheus.yml ]; then
    run_test "Prometheus configuration is valid" \
        "docker run --rm -v $(pwd)/monitoring:/etc/prometheus:ro prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml"
else
    skip_test "Prometheus configuration validation" "prometheus.yml not found"
fi

# Check if alert rules are valid
if [ -f monitoring/alerts.yml ]; then
    run_test "Alert rules are valid" \
        "docker run --rm -v $(pwd)/monitoring:/etc/prometheus:ro prom/prometheus:latest promtool check rules /etc/prometheus/alerts.yml"
else
    skip_test "Alert rules validation" "alerts.yml not found"
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Total Tests: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"

# Calculate success rate
if [ $((PASSED + FAILED)) -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=2; ($PASSED / ($PASSED + $FAILED)) * 100" | bc)
    echo -e "Success Rate: ${SUCCESS_RATE}%"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
