#!/bin/bash

# Horizen Network Health Check Script
# Verifies all services are running properly
# Supports retry logic, JSON output, and detailed error reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
JSON_OUTPUT=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json           Output results in JSON format"
            echo "  --verbose, -v    Enable verbose output"
            echo "  --retries N      Number of retries for failing checks (default: 3)"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${GREEN}=== Horizen Network Health Check ===${NC}"
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}Error: .env file not found${NC}"
    fi
    exit 1
fi

ERRORS=0
declare -A SERVICE_STATUS
declare -A SERVICE_DETAILS
START_TIME=$(date +%s)

# Helper function to retry a command
retry_command() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command" 2>/dev/null; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
                echo -e "${YELLOW}  Retry $attempt/$max_attempts failed, waiting ${delay}s...${NC}"
            fi
            sleep $delay
        fi
        ((attempt++))
    done
    
    return 1
}

# Helper function to check container health with retry
check_container_with_retry() {
    local container=$1
    local service_name=$2
    
    if retry_command $MAX_RETRIES $RETRY_DELAY "docker ps --format '{{.Names}}' | grep -q '^${container}$'"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        
        if [ "$status" = "running" ]; then
            if [ "$health" != "none" ]; then
                if [ "$health" = "healthy" ] || [ "$health" = "starting" ]; then
                    SERVICE_STATUS[$service_name]="up"
                    SERVICE_DETAILS[$service_name]="running (health: $health)"
                    return 0
                else
                    SERVICE_STATUS[$service_name]="degraded"
                    SERVICE_DETAILS[$service_name]="running but unhealthy"
                    return 1
                fi
            else
                SERVICE_STATUS[$service_name]="up"
                SERVICE_DETAILS[$service_name]="running (no health check)"
                return 0
            fi
        else
            SERVICE_STATUS[$service_name]="down"
            SERVICE_DETAILS[$service_name]="not running (status: $status)"
            return 1
        fi
    else
        SERVICE_STATUS[$service_name]="down"
        SERVICE_DETAILS[$service_name]="container not found"
        return 1
    fi
}

# Check Docker containers
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Docker containers...${NC}"
fi

CONTAINERS=("horizen-nginx" "horizen-zookeeper" "horizen-postgres" "horizen-mongodb" "horizen-redis" "horizen-druid-coordinator" "horizen-druid-broker" "horizen-druid-router" "horizen-druid-historical" "horizen-druid-middlemanager")

for container in "${CONTAINERS[@]}"; do
    # Extract service name from container name (remove horizen- prefix)
    service_name=$(echo "$container" | sed 's/^horizen-//')
    
    if check_container_with_retry "$container" "$service_name"; then
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓ $container is ${SERVICE_DETAILS[$service_name]}${NC}"
        fi
    else
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗ $container: ${SERVICE_DETAILS[$service_name]}${NC}"
        fi
        ((ERRORS++))
    fi
done

# Check Nginx
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Nginx...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "curl -f -s http://localhost/health > /dev/null 2>&1"; then
    SERVICE_STATUS["nginx_http"]="up"
    SERVICE_DETAILS["nginx_http"]="responding to HTTP requests"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Nginx is responding${NC}"
    fi
else
    SERVICE_STATUS["nginx_http"]="down"
    SERVICE_DETAILS["nginx_http"]="not responding to HTTP requests"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ Nginx is not responding${NC}"
    fi
    ((ERRORS++))
fi

# Check Nginx configuration
if retry_command 2 2 "docker exec horizen-nginx nginx -t > /dev/null 2>&1"; then
    SERVICE_STATUS["nginx_config"]="valid"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    fi
else
    SERVICE_STATUS["nginx_config"]="invalid"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ Nginx configuration has errors${NC}"
    fi
    ((ERRORS++))
fi

# Check PostgreSQL
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking PostgreSQL...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-postgres pg_isready -U ${POSTGRES_USER} > /dev/null 2>&1"; then
    SERVICE_STATUS["postgres"]="up"
    SERVICE_DETAILS["postgres"]="ready"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
    fi
    
    # Check connection
    if retry_command 2 2 "docker exec horizen-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c 'SELECT 1;' > /dev/null 2>&1"; then
        SERVICE_STATUS["postgres_connection"]="up"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓ PostgreSQL connection successful${NC}"
        fi
    else
        SERVICE_STATUS["postgres_connection"]="down"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗ PostgreSQL connection failed${NC}"
        fi
        ((ERRORS++))
    fi
else
    SERVICE_STATUS["postgres"]="down"
    SERVICE_DETAILS["postgres"]="not ready"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ PostgreSQL is not ready${NC}"
    fi
    ((ERRORS++))
fi

# Check MongoDB
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking MongoDB...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-mongodb mongosh --quiet --eval \"db.adminCommand('ping').ok\" 2>/dev/null | grep -q '1'"; then
    SERVICE_STATUS["mongodb"]="up"
    SERVICE_DETAILS["mongodb"]="responding"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ MongoDB is responding${NC}"
    fi
else
    SERVICE_STATUS["mongodb"]="down"
    SERVICE_DETAILS["mongodb"]="not responding"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ MongoDB is not responding${NC}"
    fi
    ((ERRORS++))
fi

# Check Redis
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Redis...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} ping 2>/dev/null | grep -q PONG"; then
    SERVICE_STATUS["redis"]="up"
    SERVICE_DETAILS["redis"]="responding"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Redis is responding${NC}"
    fi
else
    SERVICE_STATUS["redis"]="down"
    SERVICE_DETAILS["redis"]="not responding"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ Redis is not responding${NC}"
    fi
    ((ERRORS++))
fi

# Check ZooKeeper
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking ZooKeeper...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-zookeeper zkServer.sh status > /dev/null 2>&1"; then
    SERVICE_STATUS["zookeeper"]="up"
    SERVICE_DETAILS["zookeeper"]="running"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ ZooKeeper is running${NC}"
    fi
else
    SERVICE_STATUS["zookeeper"]="down"
    SERVICE_DETAILS["zookeeper"]="not running"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ ZooKeeper is not running${NC}"
    fi
    ((ERRORS++))
fi

# Check Druid Router Console
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Druid Router...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "curl -f -s http://localhost:8888/status > /dev/null 2>&1 || docker exec horizen-druid-router curl -f -s http://localhost:8888/status > /dev/null 2>&1"; then
    SERVICE_STATUS["druid_router_api"]="up"
    SERVICE_DETAILS["druid_router_api"]="accessible"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Druid Router is accessible${NC}"
    fi
else
    SERVICE_STATUS["druid_router_api"]="starting"
    SERVICE_DETAILS["druid_router_api"]="may still be starting up"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}! Druid Router may still be starting up${NC}"
    fi
fi

# Check Druid Coordinator
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Druid Coordinator...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-druid-coordinator curl -f -s http://localhost:8081/status > /dev/null 2>&1"; then
    SERVICE_STATUS["druid_coordinator_api"]="up"
    SERVICE_DETAILS["druid_coordinator_api"]="accessible"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Druid Coordinator is accessible${NC}"
    fi
else
    SERVICE_STATUS["druid_coordinator_api"]="starting"
    SERVICE_DETAILS["druid_coordinator_api"]="may still be starting up"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}! Druid Coordinator may still be starting up${NC}"
    fi
fi

# Check Druid Broker
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking Druid Broker...${NC}"
fi

if retry_command $MAX_RETRIES $RETRY_DELAY "docker exec horizen-druid-broker curl -f -s http://localhost:8082/status > /dev/null 2>&1"; then
    SERVICE_STATUS["druid_broker_api"]="up"
    SERVICE_DETAILS["druid_broker_api"]="accessible"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Druid Broker is accessible${NC}"
    fi
else
    SERVICE_STATUS["druid_broker_api"]="starting"
    SERVICE_DETAILS["druid_broker_api"]="may still be starting up"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}! Druid Broker may still be starting up${NC}"
    fi
fi

# Check disk space
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking disk space...${NC}"
fi

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
SERVICE_STATUS["disk_space"]="ok"
SERVICE_DETAILS["disk_space"]="$DISK_USAGE% used"

if [ "$DISK_USAGE" -lt 80 ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Disk space OK ($DISK_USAGE% used)${NC}"
    fi
elif [ "$DISK_USAGE" -lt 90 ]; then
    SERVICE_STATUS["disk_space"]="warning"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}! Disk space warning ($DISK_USAGE% used)${NC}"
    fi
else
    SERVICE_STATUS["disk_space"]="critical"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ Disk space critical ($DISK_USAGE% used)${NC}"
    fi
    ((ERRORS++))
fi

# Check memory usage
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "\n${YELLOW}Checking memory usage...${NC}"
fi

MEMORY_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
SERVICE_STATUS["memory"]="ok"
SERVICE_DETAILS["memory"]="$MEMORY_USAGE% used"

if [ "$MEMORY_USAGE" -lt 80 ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓ Memory usage OK ($MEMORY_USAGE% used)${NC}"
    fi
elif [ "$MEMORY_USAGE" -lt 90 ]; then
    SERVICE_STATUS["memory"]="warning"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}! Memory usage warning ($MEMORY_USAGE% used)${NC}"
    fi
else
    SERVICE_STATUS["memory"]="critical"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗ Memory usage critical ($MEMORY_USAGE% used)${NC}"
    fi
    ((ERRORS++))
fi

# Calculate uptime
END_TIME=$(date +%s)
CHECK_DURATION=$((END_TIME - START_TIME))

# Output results
if [ "$JSON_OUTPUT" = true ]; then
    # Generate JSON output
    echo "{"
    echo "  \"status\": \"$([ $ERRORS -eq 0 ] && echo 'healthy' || echo 'unhealthy')\","
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"version\": \"1.0.0\","
    echo "  \"check_duration_seconds\": $CHECK_DURATION,"
    echo "  \"errors\": $ERRORS,"
    echo "  \"services\": {"
    
    # Output service statuses
    first=true
    for service in "${!SERVICE_STATUS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "    \"$service\": {"
        echo -n "\"status\": \"${SERVICE_STATUS[$service]}\""
        if [ -n "${SERVICE_DETAILS[$service]}" ]; then
            echo -n ", \"details\": \"${SERVICE_DETAILS[$service]}\""
        fi
        echo -n "}"
    done
    
    echo ""
    echo "  },"
    echo "  \"resources\": {"
    echo "    \"disk_usage_percent\": $DISK_USAGE,"
    echo "    \"memory_usage_percent\": $MEMORY_USAGE"
    echo "  }"
    echo "}"
else
    # Summary
    echo -e "\n${GREEN}=== Health Check Complete ===${NC}"
    echo -e "Check duration: ${CHECK_DURATION}s"
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}All checks passed!${NC}"
        exit 0
    else
        echo -e "${RED}Found $ERRORS error(s)${NC}"
        exit 1
    fi
fi

# Exit with appropriate code
[ $ERRORS -eq 0 ] && exit 0 || exit 1
