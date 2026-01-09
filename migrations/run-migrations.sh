#!/bin/bash

# Horizen Network Database Migration Runner
# Runs SQL migration files in order

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Database Migrations ===${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
elif [ -f "$SCRIPT_DIR/../.env.production" ]; then
    source "$SCRIPT_DIR/../.env.production"
else
    echo -e "${RED}Error: No .env file found${NC}"
    exit 1
fi

# Database configuration
DB_HOST="${POSTGRES_HOST:-postgres}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-horizen_network}"
DB_USER="${POSTGRES_USER:-druid}"
DB_PASSWORD="${POSTGRES_PASSWORD}"

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: POSTGRES_PASSWORD not set${NC}"
    exit 1
fi

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

# Function to run a migration
run_migration() {
    local file=$1
    local filename=$(basename "$file")
    
    echo -e "${YELLOW}Running migration: ${filename}${NC}"
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1 | tee /tmp/migration_output.log; then
        echo -e "${GREEN}✓ Migration ${filename} completed successfully${NC}\n"
        
        # Record migration in database
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
            INSERT INTO schema_migrations (migration_name, applied_at)
            VALUES ('${filename}', NOW())
            ON CONFLICT (migration_name) DO NOTHING;
EOF
        return 0
    else
        echo -e "${RED}✗ Migration ${filename} failed${NC}"
        cat /tmp/migration_output.log
        return 1
    fi
}

# Create migrations table if it doesn't exist
echo -e "${BLUE}Creating schema_migrations table if not exists...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
    CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        applied_at TIMESTAMP DEFAULT NOW()
    );
    
    CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at 
        ON schema_migrations(applied_at DESC);
EOF

echo -e "${GREEN}✓ Schema migrations table ready${NC}\n"

# Get list of applied migrations
APPLIED_MIGRATIONS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT migration_name FROM schema_migrations;")

# Run migrations in order
ERRORS=0
APPLIED=0
SKIPPED=0

for migration_file in "$SCRIPT_DIR"/*.sql; do
    if [ -f "$migration_file" ]; then
        filename=$(basename "$migration_file")
        
        # Check if migration already applied
        if echo "$APPLIED_MIGRATIONS" | grep -q "$filename"; then
            echo -e "${BLUE}⊘ Skipping ${filename} (already applied)${NC}"
            ((SKIPPED++))
        else
            if run_migration "$migration_file"; then
                ((APPLIED++))
            else
                ((ERRORS++))
                
                # Ask user if they want to continue
                if [ "$ERRORS" -lt 3 ]; then
                    read -p "Continue with remaining migrations? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        echo -e "${YELLOW}Migration process stopped by user${NC}"
                        break
                    fi
                else
                    echo -e "${RED}Too many errors. Stopping migration process.${NC}"
                    break
                fi
            fi
        fi
    fi
done

# Summary
echo -e "\n${GREEN}=== Migration Summary ===${NC}"
echo -e "Applied: ${GREEN}$APPLIED${NC}"
echo -e "Skipped: ${BLUE}$SKIPPED${NC}"
echo -e "Errors: ${RED}$ERRORS${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "\n${GREEN}All migrations completed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some migrations failed. Please review errors above.${NC}"
    exit 1
fi
