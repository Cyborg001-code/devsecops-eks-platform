import os
import logging
from fastapi import FastAPI, HTTPException
from pythonjsonlogger import jsonlogger
from feature_engineering import fetch_logs_from_s3, extract_features
from model import (
    train_model, save_model_to_s3,
    load_model_from_s3, predict_anomaly
)

logger = logging.getLogger("ai-service")
handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

S3_LOGS_BUCKET = os.getenv("S3_LOGS_BUCKET", "devsecops-logs-14ae8678")
S3_MODELS_BUCKET = os.getenv("S3_MODELS_BUCKET", "devsecops-models-14ae8678")
S3_LOGS_PREFIX = os.getenv("S3_LOGS_PREFIX", "logs/")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")

app = FastAPI(title="AI Anomaly Detection Service")

@app.get("/health")
def health():
    return {"status": "healthy", "service": "ai-anomaly-detection"}

@app.post("/train")
def train():
    """Fetch logs from S3, extract features, train model."""
    try:
        logger.info("Starting model training")
        records = fetch_logs_from_s3(S3_LOGS_BUCKET, S3_LOGS_PREFIX)

        if not records:
            raise HTTPException(
                status_code=400,
                detail="No log records found in S3."
            )

        features = extract_features(records)

        if features.empty:
            raise HTTPException(
                status_code=400,
                detail="Could not extract features from logs."
            )

        logger.info(f"Extracted features from {len(records)} log records")
        train_model(features)
        save_model_to_s3(S3_MODELS_BUCKET)

        return {
            "status": "success",
            "message": f"Model trained on {len(records)} log records",
            "features": features.to_dict(orient="records")
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Training failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict")
def predict():
    """Load model, fetch latest logs, predict anomaly."""
    try:
        logger.info("Running anomaly prediction")
        model, scaler = load_model_from_s3(S3_MODELS_BUCKET)
        records = fetch_logs_from_s3(S3_LOGS_BUCKET, S3_LOGS_PREFIX)

        if not records:
            raise HTTPException(
                status_code=400,
                detail="No recent logs found."
            )

        features = extract_features(records)

        if features.empty:
            raise HTTPException(
                status_code=400,
                detail="Could not extract features."
            )

        result = predict_anomaly(model, scaler, features)
        logger.info(f"Prediction: {result}")

        if result["is_anomaly"] and SLACK_WEBHOOK_URL:
            send_slack_alert(result)

        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def send_slack_alert(result: dict):
    """Send anomaly alert to Slack."""
    import httpx
    features = result["features"]
    message = {
        "text": (
            f":rotating_light: *Anomaly Detected!*\n"
            f"• Error Rate: {features.get('error_rate', 0):.2%}\n"
            f"• 5xx Count: {features.get('count_5xx', 0)}\n"
            f"• Avg Latency: {features.get('avg_latency_ms', 0):.1f}ms\n"
            f"• Anomaly Score: {result['anomaly_score']:.4f}"
        )
    }
    try:
        httpx.post(SLACK_WEBHOOK_URL, json=message, timeout=5)
        logger.info("Slack alert sent")
    except Exception as e:
        logger.error(f"Slack alert failed: {e}")