import time
import random
import logging
from fastapi import FastAPI, Request, Response
from pythonjsonlogger import jsonlogger

# Setup structured JSON logger
logger = logging.getLogger("app")
handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

app = FastAPI()

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = round((time.time() - start_time) * 1000, 2)

    logger.info("request", extra={
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "method": request.method,
        "path": request.url.path,
        "status_code": response.status_code,
        "response_time_ms": duration,
        "client_ip": request.client.host if request.client else "unknown"
    })
    return response

@app.get("/")
def root():
    return {"message": "DevSecOps App Running"}

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/api/data")
def get_data():
    # Simulate occasional slow responses
    delay = random.uniform(0.01, 0.3)
    time.sleep(delay)
    return {"data": "sample response", "items": random.randint(1, 100)}

@app.get("/api/error")
def trigger_error():
    # Simulate error endpoint for testing anomaly detection
    return Response(status_code=500, content="Internal Server Error")
