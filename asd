#!/usr/bin/env python3
import serial
import time
import struct
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
from datetime import datetime

# Serial port settings
SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 115200

# InfluxDB settings
INFLUXDB_URL = "http://localhost:8086"
INFLUXDB_TOKEN = "your-token-here"
INFLUXDB_ORG = "your-org"
INFLUXDB_BUCKET = "sensor_data"

client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
write_api = client.write_api(write_options=SYNCHRONOUS)

def parse_raw_data(data):
    """Extract sensor values from raw data"""
    try:
        # Display as hexadecimal string
        hex_str = ' '.join(f'{b:02x}' for b in data)
        print(f"Raw data (hex): {hex_str}")
        
        # Pattern search: node_id(2) + seqNo(2) + sensor_data(12)
        if len(data) >= 16:
            # Little-endian
            node_id = struct.unpack('<H', data[0:2])[0]
            seq_no = struct.unpack('<H', data[2:4])[0]
            sensors = list(struct.unpack('<6H', data[4:16]))
            
            return {
                'node_id': node_id,
                'seq_no': seq_no,
                'sensors': sensors
            }
    except Exception as e:
        print(f"Parsing error: {e}")
    
    return None

def save_to_influxdb(data):
    """Save to InfluxDB"""
    try:
        point = Point("sensor_data") \
            .tag("node_id", str(data['node_id'])) \
            .field("sequence", data['seq_no'])
        
        # Save sensor values (modify according to actual sensor meanings)
        sensor_names = ["temperature", "humidity", "light", "battery", "sensor4", "sensor5"]
        
        for i, value in enumerate(data['sensors']):
            point = point.field(sensor_names[i], value)
        
        point = point.time(datetime.utcnow())
        
        write_api.write(bucket=INFLUXDB_BUCKET, org=INFLUXDB_ORG, record=point)
        print(f"✓ Save complete")
        
    except Exception as e:
        print(f"✗ Save error: {e}")

def main():
    print("=" * 70)
    print("TinyOS Sensor Raw Data Receiver")
    print("=" * 70)
    
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"✓ Connected: {SERIAL_PORT} @ {BAUD_RATE}bps\n")
        
        while True:
            if ser.in_waiting > 0:
                # Wait until enough data is accumulated
                time.sleep(0.1)
                
                data = ser.read(ser.in_waiting)
                
                if len(data) > 0:
                    print(f"\nReceived ({len(data)} bytes)")
                    
                    parsed = parse_raw_data(data)
                    
                    if parsed:
                        print(f"Node: {parsed['node_id']}, Sequence: {parsed['seq_no']}")
                        print(f"Sensors: {parsed['sensors']}")
                        save_to_influxdb(parsed)
                    
                    print("-" * 70)
            
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\n\nTerminated")
    finally:
        if 'ser' in locals():
            ser.close()
        client.close()

if __name__ == "__main__":
    main()
