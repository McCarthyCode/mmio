# Build stage
FROM python:slim AS builder

WORKDIR /build
COPY ./app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:slim

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=latest

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.revision=$VCS_REF
LABEL org.opencontainers.image.version=$VERSION
LABEL authors="Matt McCarthy"
LABEL maintainer="matt@mattmccarthy.io"
LABEL description="mmio - Professional profile webpage for Matt McCarthy"

COPY --from=builder /root/.local /root/.local
COPY ./app /app

WORKDIR /app
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/').read()"

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "--timeout", "120", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
