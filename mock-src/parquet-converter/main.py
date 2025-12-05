import os
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("parquet-converter")

def main():
    source_bucket = os.environ.get("SOURCE_BUCKET", "unknown")
    dest_bucket = os.environ.get("DEST_BUCKET", "unknown")
    
    logger.info(f"Starting conversion job from {source_bucket} to {dest_bucket}...")
    time.sleep(5) # Simulate work
    logger.info("Conversion complete.")

if __name__ == "__main__":
    main()
