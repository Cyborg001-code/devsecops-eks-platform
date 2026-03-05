import joblib
import boto3
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import logging

logger = logging.getLogger(__name__)

MODEL_LOCAL_PATH = "/tmp/isolation_forest.pkl"
SCALER_LOCAL_PATH = "/tmp/scaler.pkl"

FEATURE_COLUMNS = [
    "requests_per_window",
    "error_rate",
    "count_4xx",
    "count_5xx",
    "avg_latency_ms",
    "std_latency_ms",
    "unique_ips",
]


def train_model(df: pd.DataFrame, contamination: float = 0.05):
    """Train Isolation Forest model."""
    if df.empty:
        raise ValueError("Not enough data to train. Check S3 logs.")

    X = df[FEATURE_COLUMNS].fillna(0).values
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = IsolationForest(
        contamination=contamination,
        random_state=42,
        n_estimators=100
    )
    model.fit(X_scaled)

    joblib.dump(model, MODEL_LOCAL_PATH)
    joblib.dump(scaler, SCALER_LOCAL_PATH)

    logger.info(f"Model trained on {len(df)} samples")
    return model, scaler


def save_model_to_s3(bucket: str):
    """Upload trained model to S3."""
    s3 = boto3.client("s3")
    s3.upload_file(MODEL_LOCAL_PATH, bucket, "models/isolation_forest.pkl")
    s3.upload_file(SCALER_LOCAL_PATH, bucket, "models/scaler.pkl")
    logger.info(f"Model saved to s3://{bucket}/models/")


def load_model_from_s3(bucket: str):
    """Download model from S3 and load it."""
    s3 = boto3.client("s3")
    s3.download_file(bucket, "models/isolation_forest.pkl", MODEL_LOCAL_PATH)
    s3.download_file(bucket, "models/scaler.pkl", SCALER_LOCAL_PATH)
    model = joblib.load(MODEL_LOCAL_PATH)
    scaler = joblib.load(SCALER_LOCAL_PATH)
    logger.info("Model loaded from S3")
    return model, scaler


def predict_anomaly(model, scaler, features: pd.DataFrame) -> dict:
    """Run anomaly prediction on feature vector."""
    X = features[FEATURE_COLUMNS].fillna(0).values
    X_scaled = scaler.transform(X)
    prediction = model.predict(X_scaled)
    score = model.decision_function(X_scaled)

    return {
        "is_anomaly": bool(prediction[0] == -1),
        "anomaly_score": float(score[0]),
        "features": features.to_dict(orient="records")[0]
    }