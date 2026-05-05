FROM python:slim

COPY ./app /app
WORKDIR /app
RUN pip install --no-cache-dir flask gunicorn

EXPOSE 8080

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "app:app"]
