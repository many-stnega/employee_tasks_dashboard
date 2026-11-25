FROM python:3.12-slim-bookworm

ENV TASKS_DATA_DIR=/data \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir --disable-pip-version-check -r requirements.txt

COPY backend_python/ /app/backend_python/
COPY web_dashboard/ /app/web_dashboard/

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).read(1)" || exit 1

CMD ["python", "/app/backend_python/start.py"]
