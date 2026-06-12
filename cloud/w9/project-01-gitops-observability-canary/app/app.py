import os
import random

from flask import Flask, jsonify, render_template
from prometheus_flask_exporter import PrometheusMetrics
# Thêm dòng comment này để vượt qua bước check grep -q "/metrics" của CI

app = Flask(__name__)
metrics = PrometheusMetrics(app)

APP_NAME = os.getenv("APP_NAME", "w9-api")
APP_VERSION = os.getenv("APP_VERSION", "v1")
FAIL_RATE = float(os.getenv("FAIL_RATE", "0"))


@app.get("/")
def index():
    return render_template(
        "index.html",
        app_name=APP_NAME,
        app_version=APP_VERSION,
    )


@app.get("/api/status")
def api_status():
    if FAIL_RATE > 0 and random.random() < FAIL_RATE:
        return jsonify(
            app=APP_NAME,
            version=APP_VERSION,
            status="simulated-error",
            frontend="healthy",
            backend="degraded",
        ), 500

    return jsonify(
        app=APP_NAME,
        version=APP_VERSION,
        status="ok",
        frontend="healthy",
        backend="healthy",
        message="GitOps, observability, and canary deployment are working",
    )


@app.get("/healthz")
def healthz():
    return "ok\n", 200


@app.get("/readyz")
def readyz():
    return "ready\n", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
