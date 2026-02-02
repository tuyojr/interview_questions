# Cloud Run Hello + DB Test Image

This repository builds a minimal Python container image designed for Google Cloud Run services. It is based on the Cloud Run `“Hello World”` sample and adds a `/db-test` endpoint to validate Postgres connectivity.

## What the image does

- `/` returns a simple “Hello NAME!” response.
- `/db-test` performs a short Postgres connection test using environment variables, logs success/failure, and returns:
  - `200 OK` with `DB connection test: success` on success
  - `500` with `DB connection test: failed` on failure

No secrets are logged or returned in responses.

## Environment variables

The container expects the following variables at runtime:

- `DB_HOST` (required)
- `DB_NAME` (required)
- `DB_USER` (required)
- `DB_PASSWORD` (required)

Optional:

- `NAME` (defaults to `World`)
- `PORT` (defaults to `8080`)

## Local usage (Docker Compose)

```BASH
docker compose up --build
```

Then open:

- `http://localhost:8080/`
- `http://localhost:8080/db-test`

## Cloud Run usage

Build and push to Docker Hub (example):

```BASH
docker build -t docker.io/<your-username>/cloudrun-hello-dbtest:latest .
docker push docker.io/<your-username>/cloudrun-hello-dbtest:latest
```

Deploy to Cloud Run and set environment variables (via Terraform or gcloud). The service must be attached to a VPC connector if you are connecting to a private Cloud SQL instance.

## Credits

This image is adapted from the Cloud Run Hello World sample:

- [https://docs.cloud.google.com/run/docs/samples/cloudrun-helloworld-service#cloudrun_helloworld_service-python](https://docs.cloud.google.com/run/docs/samples/cloudrun-helloworld-service#cloudrun_helloworld_service-python)
