import os
import pickle
import boto3
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import logging

logger = logging.getLogger("ai-service")

MODEL_FILE = "/tmp/isolation_forest.pkl"
SCALER_FILE = "/tmp/scaler.pkl"

model_instance = None
scaler_instance = None


def train_model(features_df):
    """Train IsolationForest model on extracted features."""
    global model_instance, scaler_instance

    scaler = StandardScaler()
    X = scaler.fit_transform(features_df)

    model = IsolationForest(
        n_estimators=100,
        contamination=0.1,
        random_state=42
    )
    model.fit(X)

    model_instance = model
    scaler_instance = scaler

    with open(MODEL_FILE, "wb") as f:
        pickle.dump(model, f)
    with open(SCALER_FILE, "wb") as f:
        pickle.dump(scaler, f)

    logger.info("Model trained and saved locally")


def save_model_to_s3(bucket: str):
    """Upload model and scaler to S3."""
    s3 = boto3.client("s3")
    s3.upload_file(MODEL_FILE, bucket, "models/isolation_forest.pkl")
    s3.upload_file(SCALER_FILE, bucket, "models/scaler.pkl")
    logger.info(f"Model saved to s3://{bucket}/models/")


def load_model_from_s3(bucket: str):
    """Download model and scaler from S3."""
    global model_instance, scaler_instance

    if model_instance and scaler_instance:
        return model_instance, scaler_instance

    s3 = boto3.client("s3")
    s3.download_file(bucket, "models/isolation_forest.pkl", MODEL_FILE)
    s3.download_file(bucket, "models/scaler.pkl", SCALER_FILE)

    with open(MODEL_FILE, "rb") as f:
        model_instance = pickle.load(f)
    with open(SCALER_FILE, "rb") as f:
        scaler_instance = pickle.load(f)

    logger.info("Model loaded from S3")
    return model_instance, scaler_instance


def predict_anomaly(model, scaler, features_df):
    """Predict anomaly using trained model."""
    X = scaler.transform(features_df)
    raw_score = model.score_samples(X)[0]
    prediction = model.predict(X)[0]

    # score_samples returns negative values
    # more negative = more anomalous
    # threshold: below -0.1 is anomaly
    ANOMALY_THRESHOLD = -0.1

    is_anomaly = bool(raw_score < ANOMALY_THRESHOLD)
    anomaly_score = round(float(raw_score), 4)

    features_dict = features_df.to_dict(orient="records")[0]

    return {
        "is_anomaly": is_anomaly,
        "anomaly_score": anomaly_score,
        "raw_score": round(float(raw_score), 4),
        "features": features_dict
    }