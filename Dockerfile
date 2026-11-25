FROM python:3.12-slim-bookworm

ENV TZ=Asia/Yangon \
    TASKS_DATA_DIR=/usr/share/nginx/html/data \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx tzdata \
    && ln -snf /usr/share/zoneinfo/Asia/Yangon /etc/localtime \
    && echo Asia/Yangon > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir --disable-pip-version-check -r requirements.txt

COPY nginx.conf /etc/nginx/nginx.conf
COPY web_dashboard/ /usr/share/nginx/html/
COPY json_data_records/ /usr/share/nginx/html/data/
COPY backend_python/ /app/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1/', timeout=2).read(1)" || exit 1

CMD ["python", "/app/start.py"]
