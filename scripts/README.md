# PostGIS Docker Setup for Taiwan GeoJSON Data

This directory contains scripts to set up a PostGIS Docker container and load GeoJSON files for GIS operations.

## Files

- `docker-compose.yml` - Docker Compose configuration for PostGIS
- `setup_postgis.sh` - Main orchestration script
- `load_geojson.py` - Python script to load GeoJSON into PostGIS tables
- `README.md` - This documentation

## Prerequisites

- Docker and Docker Compose
- Python 3 with psycopg2 library (`pip install psycopg2-binary`)

## Quick Start

1. **Start PostGIS container:**
   ```bash
   ./setup_postgis.sh --start
   ```

2. **Load a GeoJSON file:**
   ```bash
   ./setup_postgis.sh ../city/city.geo.json city_boundaries
   ```

3. **Check status:**
   ```bash
   ./setup_postgis.sh --status
   ```

4. **Stop container:**
   ```bash
   ./setup_postgis.sh --stop
   ```

## Database Connection

- **Host:** localhost
- **Port:** 5432
- **Database:** taiwan_gis
- **User:** gis_user
- **Password:** gis_password

## Usage Examples

### Loading Taiwan City Boundaries
```bash
./setup_postgis.sh ../city/city.geo.json city_boundaries
```

### Loading Cunli Data
```bash
./setup_postgis.sh ../cunli/geo/20240807.json cunli_2024
```

### Loading Base Code Data
```bash
./setup_postgis.sh ../base/geo/10002/10002010.json base_10002_010
```

## Script Options

- `--start` - Start PostGIS container only
- `--stop` - Stop PostGIS container
- `--status` - Check container status
- `--help` - Show help message

## Features

- Automatic table creation based on GeoJSON properties
- Spatial indexing for geometry columns
- Support for various GeoJSON property types
- Health checks for container readiness
- Colored output for better visibility

## GIS Operations

Once data is loaded, you can perform various GIS operations:

```sql
-- Connect to database
psql -h localhost -U gis_user -d taiwan_gis

-- Basic geometry queries
SELECT ST_AsText(geom) FROM city_boundaries LIMIT 1;

-- Spatial queries
SELECT * FROM city_boundaries WHERE ST_Contains(geom, ST_GeomFromText('POINT(121.5 25.0)', 4326));

-- Area calculations
SELECT *, ST_Area(geom) as area FROM city_boundaries;
```

## Troubleshooting

- If PostgreSQL connection fails, ensure Docker is running and container is healthy
- Check container logs: `docker-compose logs postgis`
- Verify Python dependencies are installed
- Ensure GeoJSON file exists and is valid