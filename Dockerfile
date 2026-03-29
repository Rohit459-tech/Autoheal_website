# Small, production-ish image for Flask + Gunicorn
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps (curl for optional debugging / health checks)
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 5000

# Gunicorn runs the Flask app object exposed in app/app.py
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app.app:app", "--workers", "2", "--threads", "4", "--timeout", "30"]

