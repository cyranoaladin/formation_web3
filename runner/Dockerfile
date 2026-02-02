FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd -m -u 1000 runner

WORKDIR /workspace/in

RUN mkdir -p /runner
COPY entrypoint.py /runner/entrypoint.py
RUN chmod 0755 /runner/entrypoint.py

USER 1000:1000
