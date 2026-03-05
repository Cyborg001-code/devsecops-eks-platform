import json
import pandas as pd
import boto3
import logging

logger = logging.getLogger(__name__)

def parse_log_line(line: str) -> dict:
    """Parse a single JSON log line from Fluent Bit."""
    try:
        data = json.loads(line)
        # Fluent Bit wraps logs in a "log" field as JSON string
        if "log" in data:
            try:
                inner = json.loads(data["log"])
                # Only return structured app logs, skip plain uvicorn logs
                if "status_code" in inner:
                    return inner
                return {}
            except Exception:
                return {}
        # Direct log without nesting
        if "status_code" in data:
            return data
        return {}
    except Exception:
        return {}

def fetch_logs_from_s3(bucket: str, prefix: str) -> list:
    """Fetch log files from S3 and parse them."""
    s3 = boto3.client("s3")
    records = []

    try:
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        objects = response.get("Contents", [])

        if not objects:
            logger.warning(f"No objects found in s3://{bucket}/{prefix}")
            return records

        for obj in objects[-20:]:
            try:
                body = s3.get_object(
                    Bucket=bucket, Key=obj["Key"]
                )["Body"]
                content = body.read().decode("utf-8")
                for line in content.strip().split("\n"):
                    if line:
                        parsed = parse_log_line(line)
                        if parsed:
                            records.append(parsed)
            except Exception as e:
                logger.error(f"Error reading {obj['Key']}: {e}")

    except Exception as e:
        logger.error(f"Error listing S3 objects: {e}")

    return records

def extract_features(records: list) -> pd.DataFrame:
    """Extract feature vector from log records."""
    if not records:
        return pd.DataFrame()

    df = pd.DataFrame(records)

    required = ["status_code", "response_time_ms", "client_ip"]
    for col in required:
        if col not in df.columns:
            df[col] = 0

    df["status_code"] = pd.to_numeric(
        df["status_code"], errors="coerce"
    ).fillna(200)
    df["response_time_ms"] = pd.to_numeric(
        df["response_time_ms"], errors="coerce"
    ).fillna(0)

    total = len(df)
    if total == 0:
        return pd.DataFrame()

    features = {
        "requests_per_window": total,
        "error_rate": len(df[df["status_code"] >= 500]) / total,
        "count_4xx": len(df[df["status_code"].between(400, 499)]),
        "count_5xx": len(df[df["status_code"] >= 500]),
        "avg_latency_ms": df["response_time_ms"].mean(),
        "std_latency_ms": df["response_time_ms"].std(ddof=0),
        "unique_ips": df["client_ip"].nunique()
        if "client_ip" in df.columns else 0,
    }

    return pd.DataFrame([features])