#!/bin/bash

# Horizen Network Health API Script
# Generates health check JSON for API endpoints
# Can be used with Nginx or as a standalone API

set -e

# Configuration
HEALTH_CHECK_SCRIPT="/opt/horizen-network-deploy/scripts/health-check.sh"
VERSION="1.0.0"

# Load environment variables if available
if [ -f /opt/horizen-network-deploy/.env ]; then
    source /opt/horizen-network-deploy/.env 2>/dev/null || true
fi

# Function to generate health JSON
generate_health_json() {
    local endpoint_type="$1"
    
    case "$endpoint_type" in
        "health")
            # Basic health check
            if [ -f "$HEALTH_CHECK_SCRIPT" ]; then
                # Run health check and capture JSON output
                $HEALTH_CHECK_SCRIPT --json 2>/dev/null || echo '{"status":"error","message":"Health check failed"}'
            else
                # Fallback basic health check
                cat <<EOF
{
  "status": "healthy",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "services": {
    "nginx": "$(docker ps --filter name=horizen-nginx --format '{{.Status}}' | grep -q 'Up' && echo 'up' || echo 'down')",
    "druid": "$(docker ps --filter name=horizen-druid-router --format '{{.Status}}' | grep -q 'Up' && echo 'up' || echo 'down')",
    "postgres": "$(docker ps --filter name=horizen-postgres --format '{{.Status}}' | grep -q 'Up' && echo 'up' || echo 'down')",
    "mongodb": "$(docker ps --filter name=horizen-mongodb --format '{{.Status}}' | grep -q 'Up' && echo 'up' || echo 'down')",
    "redis": "$(docker ps --filter name=horizen-redis --format '{{.Status}}' | grep -q 'Up' && echo 'up' || echo 'down')"
  }
}
EOF
            fi
            ;;
        "ready")
            # Readiness check - all services must be up
            local all_ready=true
            
            # Check critical services
            docker ps --filter name=horizen-nginx --format '{{.Status}}' | grep -q 'Up' || all_ready=false
            docker ps --filter name=horizen-postgres --format '{{.Status}}' | grep -q 'Up' || all_ready=false
            docker ps --filter name=horizen-druid-coordinator --format '{{.Status}}' | grep -q 'Up' || all_ready=false
            docker ps --filter name=horizen-druid-broker --format '{{.Status}}' | grep -q 'Up' || all_ready=false
            
            if [ "$all_ready" = true ]; then
                cat <<EOF
{
  "status": "ready",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "message": "All critical services are ready"
}
EOF
            else
                cat <<EOF
{
  "status": "not_ready",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "message": "Some critical services are not ready"
}
EOF
            fi
            ;;
        "live")
            # Liveness check - basic service is alive
            if docker ps --filter name=horizen-nginx --format '{{.Status}}' | grep -q 'Up'; then
                cat <<EOF
{
  "status": "alive",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION"
}
EOF
            else
                cat <<EOF
{
  "status": "dead",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "message": "Primary service is not running"
}
EOF
            fi
            ;;
        *)
            cat <<EOF
{
  "status": "error",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "message": "Unknown endpoint type: $endpoint_type"
}
EOF
            ;;
    esac
}

# Main execution
if [ $# -eq 0 ]; then
    # Default to health endpoint
    generate_health_json "health"
else
    generate_health_json "$1"
fi
