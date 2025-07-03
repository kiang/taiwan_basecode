#!/bin/bash
#
# PostGIS Docker Setup Script
# This script sets up a PostGIS Docker container and loads specified GeoJSON files
#
# Usage: ./setup_postgis.sh [geojson_file] [table_name]
#        ./setup_postgis.sh --start (start containers only)
#        ./setup_postgis.sh --stop (stop containers)
#        ./setup_postgis.sh --status (check status)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
LOADER_SCRIPT="$SCRIPT_DIR/load_geojson.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

# Function to check if Python and required packages are available
check_python() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3 first."
        exit 1
    fi
    
    if ! python3 -c "import psycopg2" &> /dev/null; then
        print_warning "psycopg2 is not installed. Installing..."
        pip3 install psycopg2-binary
    fi
}

# Function to start PostGIS container
start_postgis() {
    print_status "Starting PostGIS container..."
    
    cd "$SCRIPT_DIR"
    
    # Create network if it doesn't exist
    docker network create taiwan_postgis_network 2>/dev/null || true
    
    # Create volume if it doesn't exist
    docker volume create postgis_data 2>/dev/null || true
    
    # Stop and remove existing container if it exists
    docker stop taiwan_postgis 2>/dev/null || true
    docker rm taiwan_postgis 2>/dev/null || true
    
    # Start PostGIS container using pure Docker CLI
    docker run -d \
        --name taiwan_postgis \
        --network taiwan_postgis_network \
        -e POSTGRES_DB=taiwan_gis \
        -e POSTGRES_USER=gis_user \
        -e POSTGRES_PASSWORD=gis_password \
        -e PGDATA=/var/lib/postgresql/data/pgdata \
        -p 5433:5432 \
        -v postgis_data:/var/lib/postgresql/data \
        -v "$SCRIPT_DIR/sql_init":/docker-entrypoint-initdb.d \
        --restart unless-stopped \
        --health-cmd "pg_isready -U gis_user -d taiwan_gis" \
        --health-interval 10s \
        --health-timeout 5s \
        --health-retries 5 \
        postgis/postgis:15-3.3
    
    print_status "Waiting for PostGIS to be ready..."
    
    # Wait for PostGIS to be ready
    timeout=60
    counter=0
    
    while [ $counter -lt $timeout ]; do
        if docker exec taiwan_postgis pg_isready -U gis_user -d taiwan_gis &> /dev/null; then
            print_status "PostGIS is ready!"
            return 0
        fi
        
        sleep 2
        counter=$((counter + 2))
        echo -n "."
    done
    
    print_error "PostGIS failed to start within $timeout seconds"
    return 1
}

# Function to stop PostGIS container
stop_postgis() {
    print_status "Stopping PostGIS container..."
    
    # Stop and remove container
    docker stop taiwan_postgis 2>/dev/null || true
    docker rm taiwan_postgis 2>/dev/null || true
    
    # Optionally remove network (but keep volume for data persistence)
    # docker network rm taiwan_postgis_network 2>/dev/null || true
    
    print_status "PostGIS container stopped"
}

# Function to check container status
check_status() {
    cd "$SCRIPT_DIR"
    echo "Container status:"
    
    # Use docker CLI directly to avoid Python library conflicts
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "taiwan_postgis"; then
        print_status "PostGIS container is running"
        
        # Check if PostGIS is ready
        if docker exec taiwan_postgis pg_isready -U gis_user -d taiwan_gis &> /dev/null; then
            print_status "PostGIS is ready for connections"
        else
            print_warning "PostGIS container is running but not ready"
        fi
    else
        print_warning "PostGIS container is not running"
    fi
}

# Function to load GeoJSON file
load_geojson() {
    local geojson_file="$1"
    local table_name="$2"
    
    if [ -z "$geojson_file" ] || [ -z "$table_name" ]; then
        print_error "Usage: $0 <geojson_file> <table_name>"
        exit 1
    fi
    
    if [ ! -f "$geojson_file" ]; then
        print_error "GeoJSON file not found: $geojson_file"
        exit 1
    fi
    
    print_status "Loading GeoJSON file: $geojson_file into table: $table_name"
    
    # Make sure PostGIS is running
    if ! docker exec taiwan_postgis pg_isready -U gis_user -d taiwan_gis &> /dev/null; then
        print_warning "PostGIS is not running. Starting it now..."
        start_postgis
    fi
    
    # Load the GeoJSON file
    python3 "$LOADER_SCRIPT" "$geojson_file" "$table_name"
    
    print_status "GeoJSON file loaded successfully!"
    print_status "You can now connect to the database with:"
    print_status "  Host: localhost"
    print_status "  Port: 5433"
    print_status "  Database: taiwan_gis"
    print_status "  User: gis_user"
    print_status "  Password: gis_password"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [geojson_file] [table_name]"
    echo ""
    echo "Options:"
    echo "  --start          Start PostGIS container only"
    echo "  --stop           Stop PostGIS container"
    echo "  --status         Check container status"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --start"
    echo "  $0 city/city.geo.json city_boundaries"
    echo "  $0 cunli/geo/20240807.json cunli_2024"
    echo "  $0 --stop"
}

# Main logic
main() {
    check_docker
    
    case "$1" in
        --start)
            start_postgis
            ;;
        --stop)
            stop_postgis
            ;;
        --status)
            check_status
            ;;
        --help)
            show_usage
            ;;
        "")
            print_error "No arguments provided"
            show_usage
            exit 1
            ;;
        *)
            check_python
            load_geojson "$1" "$2"
            ;;
    esac
}

# Run main function with all arguments
main "$@"