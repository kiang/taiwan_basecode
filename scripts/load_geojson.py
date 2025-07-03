#!/usr/bin/env python3
"""
Script to load GeoJSON files into PostGIS database
Usage: python load_geojson.py <geojson_file> <table_name>
"""

import json
import sys
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import argparse
from typing import Dict, Any, List

# Database connection parameters
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'taiwan_gis',
    'user': 'gis_user',
    'password': 'gis_password'
}

def connect_to_db():
    """Connect to PostgreSQL database"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)

def create_table_from_geojson(cursor, table_name: str, geojson_data: Dict[str, Any]):
    """Create table based on GeoJSON properties"""
    
    # Drop table if exists
    cursor.execute(f"DROP TABLE IF EXISTS {table_name}")
    
    # Analyze first feature to determine column types
    features = geojson_data.get('features', [])
    if not features:
        print("No features found in GeoJSON")
        return
    
    first_feature = features[0]
    properties = first_feature.get('properties', {})
    
    # Create column definitions
    columns = []
    columns.append("id SERIAL PRIMARY KEY")
    
    # Add property columns
    for prop_name, prop_value in properties.items():
        if isinstance(prop_value, str):
            columns.append(f"{prop_name} TEXT")
        elif isinstance(prop_value, int):
            columns.append(f"{prop_name} INTEGER")
        elif isinstance(prop_value, float):
            columns.append(f"{prop_name} REAL")
        elif isinstance(prop_value, bool):
            columns.append(f"{prop_name} BOOLEAN")
        else:
            columns.append(f"{prop_name} TEXT")
    
    # Add geometry column
    columns.append("geom GEOMETRY")
    
    # Create table
    create_sql = f"""
    CREATE TABLE {table_name} (
        {', '.join(columns)}
    )
    """
    
    cursor.execute(create_sql)
    print(f"Created table: {table_name}")

def insert_geojson_features(cursor, table_name: str, geojson_data: Dict[str, Any]):
    """Insert GeoJSON features into table"""
    
    features = geojson_data.get('features', [])
    if not features:
        return
    
    # Get column names from first feature
    first_feature = features[0]
    properties = first_feature.get('properties', {})
    prop_names = list(properties.keys())
    
    # Prepare INSERT statement
    placeholders = ', '.join(['%s'] * (len(prop_names) + 1))  # +1 for geometry
    columns = ', '.join(prop_names + ['geom'])
    
    insert_sql = f"""
    INSERT INTO {table_name} ({columns})
    VALUES ({placeholders})
    """
    
    # Insert each feature
    for feature in features:
        props = feature.get('properties', {})
        geom = feature.get('geometry', {})
        
        # Prepare values
        values = []
        for prop_name in prop_names:
            values.append(props.get(prop_name))
        
        # Add geometry as GeoJSON string
        values.append(json.dumps(geom))
        
        # Execute insert with ST_GeomFromGeoJSON
        final_sql = f"""
        INSERT INTO {table_name} ({columns})
        VALUES ({', '.join(['%s'] * len(prop_names))}, ST_GeomFromGeoJSON(%s))
        """
        
        cursor.execute(final_sql, values)
    
    print(f"Inserted {len(features)} features into {table_name}")

def create_spatial_index(cursor, table_name: str):
    """Create spatial index on geometry column"""
    index_sql = f"CREATE INDEX idx_{table_name}_geom ON {table_name} USING GIST (geom)"
    cursor.execute(index_sql)
    print(f"Created spatial index on {table_name}")

def load_geojson_to_postgis(geojson_file: str, table_name: str):
    """Main function to load GeoJSON into PostGIS"""
    
    # Check if file exists
    if not os.path.exists(geojson_file):
        print(f"Error: File {geojson_file} not found")
        sys.exit(1)
    
    # Load GeoJSON
    try:
        with open(geojson_file, 'r', encoding='utf-8') as f:
            geojson_data = json.load(f)
    except Exception as e:
        print(f"Error loading GeoJSON file: {e}")
        sys.exit(1)
    
    # Connect to database
    conn = connect_to_db()
    cursor = conn.cursor()
    
    try:
        # Create table
        create_table_from_geojson(cursor, table_name, geojson_data)
        
        # Insert features
        insert_geojson_features(cursor, table_name, geojson_data)
        
        # Create spatial index
        create_spatial_index(cursor, table_name)
        
        # Commit transaction
        conn.commit()
        print(f"Successfully loaded {geojson_file} into table {table_name}")
        
    except Exception as e:
        conn.rollback()
        print(f"Error loading data: {e}")
        sys.exit(1)
    
    finally:
        cursor.close()
        conn.close()

def main():
    parser = argparse.ArgumentParser(description='Load GeoJSON file into PostGIS database')
    parser.add_argument('geojson_file', help='Path to GeoJSON file')
    parser.add_argument('table_name', help='Name of the table to create')
    
    args = parser.parse_args()
    
    load_geojson_to_postgis(args.geojson_file, args.table_name)

if __name__ == '__main__':
    main()