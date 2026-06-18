FROM python:3.13-alpine

RUN pip install --no-cache-dir flask prometheus-flask-exporter

WORKDIR /app
COPY app.py /app/app.py

ENV FLASK_APP=app.py
EXPOSE 8080

CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]
