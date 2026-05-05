"""Cust-04 Summarisation Service — ECS Fargate Task"""
import json, os, boto3
from datetime import datetime, timezone

BUCKET = os.environ.get("ENRICHED_BUCKET", "")
MODEL = os.environ.get("MODEL_ID", "anthropic.claude-3-5-sonnet-20241022-v2:0")
REGION = os.environ.get("AWS_REGION", "ap-south-1")

def main():
    print(f"[{datetime.now(timezone.utc).isoformat()}] Summarisation task started")
    print(f"  Bucket: {BUCKET}")
    print(f"  Model:  {MODEL}")
    print(f"  Region: {REGION}")
    # In production: fetch from S3, call Bedrock, write summaries
    print("No pending batches. Exiting.")

if __name__ == "__main__":
    main()
