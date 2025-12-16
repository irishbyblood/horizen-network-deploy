#!/bin/bash

# Horizen Network Testing Script
# Integration tests, API tests, and performance benchmarks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Testing Suite ===${NC}"

# Configuration
TEST_LOG="./logs/test_$(date +%Y%m%d_%H%M%S).log"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Create log directory
mkdir -p ./logs

# Redirect output to log
exec > >(tee -a "$TEST_LOG")
exec 2>&1

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}Warning: .env file not found, using defaults${NC}"
fi

# Test categories
RUN_INTEGRATION=true
RUN_API=true
RUN_DATABASE=true
RUN_PERFORMANCE=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --integration)
            RUN_API=false
            RUN_DATABASE=false
            RUN_PERFORMANCE=false
            shift
            ;;
        --api)
            RUN_INTEGRATION=false
            RUN_DATABASE=false
            RUN_PERFORMANCE=false
            shift
            ;;
        --database)
            RUN_INTEGRATION=false
            RUN_API=false
            RUN_PERFORMANCE=false
            shift
            ;;
        --performance)
            RUN_PERFORMANCE=true
            shift
            ;;
        --all)
            RUN_INTEGRATION=true
            RUN_API=true
            RUN_DATABASE=true
            RUN_PERFORMANCE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --integration    Run integration tests only
  --api            Run API tests only
  --database       Run database tests only
  --performance    Include performance/load tests
  --all            Run all tests including performance
  --verbose, -v    Enable verbose output
  --help, -h       Show this help message

Examples:
  $0                     # Run integration, API, and database tests
  $0 --api               # Run API tests only
  $0 --all               # Run all tests including performance
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Test started at: $(date)"

# Helper functions
test_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP: $1${NC}"
    ((TESTS_SKIPPED++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    if [ "$VERBOSE" = true ]; then
        echo -e "\n${YELLOW}Running: $test_name${NC}"
    fi
    
    if eval "$test_command" > /dev/null 2>&1; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name"
        return 1
    fi
}

# ======================
# Integration Tests
# ======================
if [ "$RUN_INTEGRATION" = true ]; then
    echo -e "\n${YELLOW}=== Running Integration Tests ===${NC}"
    
    # Test: All containers are running
    run_test "All containers running" \
        "docker-compose ps | grep -v 'Exit'"
    
    # Test: Nginx responds to requests
    run_test "Nginx responds to HTTP" \
        "curl -f -s http://localhost/ > /dev/null"
    
    # Test: Health endpoint works
    run_test "Health endpoint accessible" \
        "curl -f -s http://localhost/health > /dev/null"
    
    # Test: Container networking
    run_test "Container network connectivity" \
        "docker-compose exec -T nginx ping -c 1 postgres > /dev/null"
    
    # Test: Volume mounts
    run_test "Volume mounts working" \
        "docker volume ls | grep -q druid-data"
    
    # Test: Environment variables loaded
    run_test "Environment variables set in containers" \
        "docker-compose exec -T postgres env | grep -q POSTGRES_USER"
fi

# ======================
# API Endpoint Tests
# ======================
if [ "$RUN_API" = true ]; then
    echo -e "\n${YELLOW}=== Running API Tests ===${NC}"
    
    # Test Nginx
    run_test "Nginx root endpoint" \
        "curl -f -s http://localhost/ | grep -q 'Horizen'"
    
    run_test "Nginx returns correct content type" \
        "curl -s -I http://localhost/ | grep -q 'text/html'"
    
    # Test Druid Router
    if docker ps --filter name=horizen-druid-router --format '{{.Status}}' | grep -q 'Up'; then
        run_test "Druid Router status endpoint" \
            "curl -f -s http://localhost:8888/status > /dev/null || docker exec horizen-druid-router curl -f -s http://localhost:8888/status > /dev/null"
        
        run_test "Druid Router returns JSON" \
            "curl -s http://localhost:8888/status 2>/dev/null | grep -q '\"version\"' || docker exec horizen-druid-router curl -s http://localhost:8888/status | grep -q '\"version\"'"
    else
        test_skip "Druid Router not running"
    fi
    
    # Test Druid Coordinator
    if docker ps --filter name=horizen-druid-coordinator --format '{{.Status}}' | grep -q 'Up'; then
        run_test "Druid Coordinator status endpoint" \
            "docker exec horizen-druid-coordinator curl -f -s http://localhost:8081/status > /dev/null"
    else
        test_skip "Druid Coordinator not running"
    fi
    
    # Test Druid Broker
    if docker ps --filter name=horizen-druid-broker --format '{{.Status}}' | grep -q 'Up'; then
        run_test "Druid Broker status endpoint" \
            "docker exec horizen-druid-broker curl -f -s http://localhost:8082/status > /dev/null"
        
        # Test simple SQL query
        run_test "Druid Broker SQL query" \
            "docker exec horizen-druid-broker curl -s -X POST -H 'Content-Type: application/json' http://localhost:8082/druid/v2/sql -d '{\"query\":\"SELECT 1\"}' | grep -q '\"1\"'"
    else
        test_skip "Druid Broker not running"
    fi
fi

# ======================
# Database Connection Tests
# ======================
if [ "$RUN_DATABASE" = true ]; then
    echo -e "\n${YELLOW}=== Running Database Tests ===${NC}"
    
    # PostgreSQL tests
    if docker ps --filter name=horizen-postgres --format '{{.Status}}' | grep -q 'Up'; then
        run_test "PostgreSQL is ready" \
            "docker exec horizen-postgres pg_isready -U ${POSTGRES_USER:-druid}"
        
        run_test "PostgreSQL accepts connections" \
            "docker exec horizen-postgres psql -U ${POSTGRES_USER:-druid} -d ${POSTGRES_DB:-druid_metadata} -c 'SELECT 1;'"
        
        run_test "PostgreSQL database exists" \
            "docker exec horizen-postgres psql -U ${POSTGRES_USER:-druid} -l | grep -q ${POSTGRES_DB:-druid_metadata}"
        
        # Test basic operations
        run_test "PostgreSQL can create table" \
            "docker exec horizen-postgres psql -U ${POSTGRES_USER:-druid} -d ${POSTGRES_DB:-druid_metadata} -c 'CREATE TABLE IF NOT EXISTS test_table (id INT);'"
        
        run_test "PostgreSQL can drop table" \
            "docker exec horizen-postgres psql -U ${POSTGRES_USER:-druid} -d ${POSTGRES_DB:-druid_metadata} -c 'DROP TABLE IF EXISTS test_table;'"
    else
        test_skip "PostgreSQL not running"
    fi
    
    # MongoDB tests
    if docker ps --filter name=horizen-mongodb --format '{{.Status}}' | grep -q 'Up'; then
        run_test "MongoDB responds to ping" \
            "docker exec horizen-mongodb mongosh --quiet --eval \"db.adminCommand('ping').ok\" | grep -q 1"
        
        run_test "MongoDB database exists" \
            "docker exec horizen-mongodb mongosh --quiet --eval \"db.getMongo().getDBNames()\" | grep -q ${MONGO_DB:-horizen_network}"
        
        # Test basic operations
        run_test "MongoDB can insert document" \
            "docker exec horizen-mongodb mongosh --quiet ${MONGO_DB:-horizen_network} --eval \"db.test.insertOne({test: 1})\" | grep -q acknowledged"
        
        run_test "MongoDB can query document" \
            "docker exec horizen-mongodb mongosh --quiet ${MONGO_DB:-horizen_network} --eval \"db.test.findOne({test: 1})\" | grep -q test"
        
        run_test "MongoDB can delete document" \
            "docker exec horizen-mongodb mongosh --quiet ${MONGO_DB:-horizen_network} --eval \"db.test.deleteOne({test: 1})\" | grep -q acknowledged"
    else
        test_skip "MongoDB not running"
    fi
    
    # Redis tests
    if docker ps --filter name=horizen-redis --format '{{.Status}}' | grep -q 'Up'; then
        run_test "Redis responds to PING" \
            "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD:-changeme} ping 2>/dev/null | grep -q PONG"
        
        run_test "Redis can SET key" \
            "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD:-changeme} SET test_key 'test_value' 2>/dev/null | grep -q OK"
        
        run_test "Redis can GET key" \
            "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD:-changeme} GET test_key 2>/dev/null | grep -q test_value"
        
        run_test "Redis can DEL key" \
            "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD:-changeme} DEL test_key 2>/dev/null | grep -q 1"
    else
        test_skip "Redis not running"
    fi
fi

# ======================
# Performance/Load Tests
# ======================
if [ "$RUN_PERFORMANCE" = true ]; then
    echo -e "\n${YELLOW}=== Running Performance Tests ===${NC}"
    
    # Test response times
    echo "Testing Nginx response time..."
    if command -v ab &> /dev/null; then
        # Apache Bench test
        ab -n 100 -c 10 http://localhost/ > /tmp/ab_test.txt 2>&1
        
        AVG_TIME=$(grep "Time per request" /tmp/ab_test.txt | head -1 | awk '{print $4}')
        if [ -n "$AVG_TIME" ] && [ $(echo "$AVG_TIME < 100" | bc -l) -eq 1 ]; then
            test_pass "Nginx average response time < 100ms (${AVG_TIME}ms)"
        else
            test_fail "Nginx response time too high (${AVG_TIME}ms)"
        fi
        
        rm /tmp/ab_test.txt
    else
        test_skip "Apache Bench not installed"
    fi
    
    # Test concurrent connections
    if command -v curl &> /dev/null; then
        echo "Testing concurrent requests..."
        CONCURRENT_SUCCESS=0
        for i in {1..10}; do
            curl -f -s http://localhost/ > /dev/null &
        done
        wait
        
        if [ $? -eq 0 ]; then
            test_pass "Handled 10 concurrent requests"
        else
            test_fail "Failed to handle concurrent requests"
        fi
    fi
    
    # Test database query performance
    if docker ps --filter name=horizen-postgres --format '{{.Status}}' | grep -q 'Up'; then
        echo "Testing PostgreSQL query performance..."
        START_TIME=$(date +%s%N)
        for i in {1..100}; do
            docker exec horizen-postgres psql -U ${POSTGRES_USER:-druid} -d ${POSTGRES_DB:-druid_metadata} -c "SELECT 1;" > /dev/null 2>&1
        done
        END_TIME=$(date +%s%N)
        DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
        
        if [ $DURATION -lt 5000 ]; then
            test_pass "PostgreSQL: 100 queries in ${DURATION}ms"
        else
            test_warn "PostgreSQL: 100 queries took ${DURATION}ms (>5s)"
        fi
    fi
fi

# ======================
# Test Summary
# ======================
echo -e "\n${GREEN}=== Test Summary ===${NC}"
echo "Test finished at: $(date)"
echo ""
echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""
echo "Test log: $TEST_LOG"

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi
