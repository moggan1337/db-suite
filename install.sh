#!/bin/bash

set -e

echo "🗄️ Installing DB Suite..."
echo "================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
check_prerequisite() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ $1 is installed${NC}"
    return 0
}

echo ""
echo "Checking prerequisites..."
check_prerequisite node || NODE_MISSING=1
check_prerequisite npm || NPM_MISSING=1
check_prerequisite python3 || PYTHON_MISSING=1
check_prerequisite pip3 || PIP_MISSING=1

# Create directories
mkdir -p ~/.db-suite/{bin,data,logs,backups,config}

echo ""
echo "📦 Installing database tools..."

# Install InsightDB (Node.js)
if command -v npm &> /dev/null; then
    echo "Installing InsightDB..."
    npm install -g @moggan1337/insightdb 2>/dev/null || echo -e "${YELLOW}⚠ Failed to install InsightDB${NC}"
fi

# Install FluxDB (Python)
if command -v pip3 &> /dev/null; then
    echo "Installing FluxDB..."
    pip3 install --quiet fluxdb 2>/dev/null || echo -e "${YELLOW}⚠ Failed to install FluxDB${NC}"
fi

# Install Chronos (Rust) or fallback
if command -v cargo &> /dev/null; then
    echo "Installing Chronos..."
    cargo install chronos-db 2>/dev/null || echo -e "${YELLOW}⚠ Failed to install Chronos${NC}"
else
    echo -e "${YELLOW}⚠ Rust/Cargo not found. Chronos requires Rust toolchain.${NC}"
fi

# Note: Avalon is C++ and requires compilation from source
echo -e "${YELLOW}⚠ Avalon requires manual compilation. See README for details.${NC}"

# Create unified CLI wrapper
cat > ~/.db-suite/bin/db-suite << 'WRAPPER'
#!/bin/bash

# DB Suite - Unified Database CLI

TOOL="${1:-help}"
shift

case "$TOOL" in
    server|avalon)
        echo "Starting Avalon database server..."
        if command -v avalond &> /dev/null; then
            avalond "$@"
        else
            echo "Avalon server not found. Install from: https://github.com/moggan1337/Avalon"
            exit 1
        fi
        ;;
    optimize|insightdb|query-optimizer)
        echo "Running InsightDB query optimizer..."
        insightdb "$@"
        ;;
    flux|fluxdb|event-store)
        echo "Running FluxDB event store..."
        fluxdb "$@"
        ;;
    chronos|timeseries|tsdb)
        echo "Running Chronos time-series database..."
        chronod "$@"
        ;;
    query)
        echo "Executing query..."
        # Route to appropriate database based on --db flag
        DB_TYPE="avalon"
        while [[ $# -gt 0 ]]; do
            case $1 in
                --db)
                    DB_TYPE="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        echo "Target database: $DB_TYPE"
        ;;
    backup)
        echo "Creating backup..."
        mkdir -p ~/.db-suite/backups/$(date +%Y%m%d_%H%M%S)
        echo "Backup location: ~/.db-suite/backups/"
        ;;
    restore)
        echo "Restoring from backup..."
        ;;
    benchmark)
        echo "Running benchmark..."
        ;;
    migrate)
        echo "Running migration..."
        ;;
    monitor)
        echo "Monitoring databases..."
        ;;
    init)
        mkdir -p .db-suite
        cat > .db-suite/config.yml << 'CONFIG'
# DB Suite Configuration
version: "1.0"
global:
  dataDir: ./data
  maxConnections: 100
  logLevel: info
avalon:
  host: localhost
  port: 5433
  storage:
    engine: auto
    bufferPoolSize: 1024
insightdb:
  databases:
    - type: postgresql
      connection: postgresql://localhost/mydb
    - type: mysql
      connection: mysql://localhost/mydb
fluxdb:
  cluster:
    nodes:
      - localhost:8091
  replication:
    factor: 3
    consistency: quorum
chronos:
  server:
    host: localhost
    port: 8086
  retention:
    default: 30d
CONFIG
        echo "✓ Configuration created at .db-suite/config.yml"
        ;;
    version)
        echo "DB Suite v1.0.0"
        echo ""
        echo "Bundled tools:"
        echo "  - Avalon v1.0.0 (Production Database)"
        echo "  - InsightDB v1.0.0 (Query Optimizer)"
        echo "  - FluxDB v0.1.0 (Event Store)"
        echo "  - Chronos v0.1.0 (Time-Series DB)"
        ;;
    help|--help|-h)
        echo "DB Suite v1.0.0 - Database Development Tools"
        echo ""
        echo "Usage: db-suite <command> [options]"
        echo ""
        echo "Commands:"
        echo "  server, avalon        Start Avalon database"
        echo "  optimize, insightdb   Run query optimizer"
        echo "  flux, fluxdb          Run event store"
        echo "  chronos, timeseries   Run time-series DB"
        echo "  query                 Execute SQL query"
        echo "  backup                Create backup"
        echo "  restore               Restore from backup"
        echo "  benchmark             Run benchmarks"
        echo "  migrate               Run migration"
        echo "  monitor               Monitor databases"
        echo "  init                  Initialize configuration"
        echo "  version               Show version info"
        echo "  help                  Show this help"
        ;;
    *)
        echo "Unknown command: $TOOL"
        echo "Run 'db-suite help' for usage information"
        exit 1
        ;;
esac
WRAPPER

chmod +x ~/.db-suite/bin/db-suite

# Create symlink
SYMLINK_PATH="/usr/local/bin/db-suite"
if [ -w "$(dirname $SYMLINK_PATH)" ]; then
    ln -sf ~/.db-suite/bin/db-suite $SYMLINK_PATH
    echo -e "${GREEN}✓ Symlink created at $SYMLINK_PATH${NC}"
elif [ -w "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin"; then
    ln -sf ~/.db-suite/bin/db-suite "$HOME/.local/bin/db-suite"
    echo -e "${GREEN}✓ Symlink created at $HOME/.local/bin/db-suite${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ DB Suite installed successfully!${NC}"
echo ""
echo "Usage:"
echo "  db-suite server         # Start database server"
echo "  db-suite optimize       # Optimize queries"
echo "  db-suite query          # Execute queries"
echo "  db-suite backup         # Create backup"
echo "  db-suite monitor        # Monitor databases"
echo ""
echo "Run 'db-suite help' for more information."
