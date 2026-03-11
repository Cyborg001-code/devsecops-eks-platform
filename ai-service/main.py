import os
import logging
import httpx
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

S3_LOGS_BUCKET = os.getenv("S3_LOGS_BUCKET", "")
S3_MODELS_BUCKET = os.getenv("S3_MODELS_BUCKET", "")
S3_LOGS_PREFIX = os.getenv("S3_LOGS_PREFIX", "logs/")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")

app = FastAPI(title="AI Anomaly Detection Service")


# ─── Slack Alert Functions ────────────────────────────────────────

def send_slack_message(text: str):
    """Send a message to Slack."""
    if not SLACK_WEBHOOK_URL:
        logger.warning("SLACK_WEBHOOK_URL not set")
        return
    try:
        httpx.post(SLACK_WEBHOOK_URL, json={"text": text}, timeout=5)
        logger.info("Slack alert sent")
    except Exception as e:
        logger.error(f"Slack alert failed: {e}")


def send_anomaly_alert(result: dict):
    """Send anomaly detection alert."""
    f = result["features"]
    send_slack_message(
        f":rotating_light: *Anomaly Detected on EKS!*\n"
        f"• Error Rate: {f.get('error_rate', 0):.2%}\n"
        f"• 5xx Count: {f.get('count_5xx', 0)}\n"
        f"• 4xx Count: {f.get('count_4xx', 0)}\n"
        f"• Avg Latency: {f.get('avg_latency_ms', 0):.1f}ms\n"
        f"• Requests: {f.get('requests_per_window', 0)}\n"
        f"• Anomaly Score: {result['anomaly_score']:.4f}"
    )


def send_high_error_rate_alert(error_rate: float, count_5xx: int):
    """Send alert when error rate exceeds threshold."""
    send_slack_message(
        f":warning: *High Error Rate Alert!*\n"
        f"• Error Rate: {error_rate:.2%}\n"
        f"• 5xx Errors: {count_5xx}\n"
        f"• Threshold: 20%\n"
        f"• Action: Check application logs immediately"
    )


def send_high_latency_alert(avg_latency: float):
    """Send alert when latency exceeds threshold."""
    send_slack_message(
        f":stopwatch: *High Latency Alert!*\n"
        f"• Avg Latency: {avg_latency:.1f}ms\n"
        f"• Threshold: 500ms\n"
        f"• Action: Check pod resources and scaling"
    )


def send_training_complete_alert(record_count: int):
    """Send alert when model training completes."""
    send_slack_message(
        f":brain: *AI Model Training Complete!*\n"
        f"• Records Trained: {record_count}\n"
        f"• Model: IsolationForest\n"
        f"• Status: Ready for anomaly detection"
    )


def send_no_logs_alert():
    """Send alert when no logs are found in S3."""
    send_slack_message(
        f":x: *No Logs Found in S3!*\n"
        f"• Bucket: {S3_LOGS_BUCKET}\n"
        f"• Action: Check Fluent Bit is running\n"
        f"• Command: kubectl get pods -n logging"
    )


# ─── API Endpoints ────────────────────────────────────────────────

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
            send_no_logs_alert()
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
        send_training_complete_alert(len(records))

        return {
            "status": "success",
            "message": f"Model trained on {len(records)} log records",
            "features": features.to_dict(orient="records")
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Training failed: {e}")
        send_slack_message(f":x: *Model Training Failed!*\n• Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict")
def predict():
    """Load model, fetch latest logs, predict anomaly."""
    try:
        logger.info("Running anomaly prediction")
        model, scaler = load_model_from_s3(S3_MODELS_BUCKET)
        records = fetch_logs_from_s3(S3_LOGS_BUCKET, S3_LOGS_PREFIX)

        if not records:
            send_no_logs_alert()
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

        f = result["features"]

        # Alert 1 - Anomaly detected
        if result["is_anomaly"]:
            send_anomaly_alert(result)

        # Alert 2 - High error rate (>20%) even if not anomaly
        if f.get("error_rate", 0) > 0.20 and not result["is_anomaly"]:
            send_high_error_rate_alert(
                f.get("error_rate", 0),
                f.get("count_5xx", 0)
            )

        # Alert 3 - High latency (>500ms)
        if f.get("avg_latency_ms", 0) > 500:
            send_high_latency_alert(f.get("avg_latency_ms", 0))

        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        send_slack_message(f":x: *Prediction Failed!*\n• Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))