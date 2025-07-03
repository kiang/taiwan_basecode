-- Initialize PostGIS database for Taiwan GIS data
-- This script runs automatically when the container starts

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Set default SRID for Taiwan (TWD97 / TM2 zone 121)
-- SRID 3826 is commonly used for Taiwan
-- SRID 4326 is WGS84 (GPS coordinates)

-- Create a function to set proper SRID for geometries
CREATE OR REPLACE FUNCTION set_taiwan_srid(geom geometry)
RETURNS geometry AS $$
BEGIN
    -- If geometry has no SRID, assume it's WGS84
    IF ST_SRID(geom) = 0 THEN
        RETURN ST_SetSRID(geom, 4326);
    END IF;
    RETURN geom;
END;
$$ LANGUAGE plpgsql;

-- Create a view to show all spatial tables
CREATE OR REPLACE VIEW spatial_tables AS
SELECT 
    schemaname,
    tablename,
    attname AS geometry_column,
    type AS geometry_type,
    srid
FROM geometry_columns
ORDER BY schemaname, tablename;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE taiwan_gis TO gis_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gis_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gis_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO gis_user;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO gis_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO gis_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO gis_user;