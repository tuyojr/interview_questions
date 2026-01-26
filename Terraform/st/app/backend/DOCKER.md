# Docker Setup for MuchToDo Backend

This document explains how to build and run the MuchToDo backend API using Docker.

## Prerequisites

- Docker 20.10+ installed
- Docker Compose (optional, for local development)
- AWS Secrets Manager configured (for production)

## Production Dockerfile

The production Dockerfile (`Dockerfile`) uses a multi-stage build to create a minimal, secure container image:

### Features

- **Multi-stage build**: Reduces final image size (~20MB vs ~1GB)
- **Alpine Linux base**: Minimal attack surface
- **Non-root user**: Runs as `appuser` (UID 1000) for security
- **Static binary**: No runtime dependencies required
- **Health check**: Built-in health monitoring
- **Optimized layers**: Efficient caching for faster builds

### Building the Image

From the `app/backend` directory:

```BASH
docker build -t muchtodo-backend:latest .

docker build -t muchtodo-backend:v1.0.0 .

docker buildx build --platform linux/amd64 -t muchtodo-backend:latest .
```

### Running the Container

#### With .env file (local development)

```BASH
docker run -d \
  --name muchtodo-api \
  -p 8080:8080 \
  --env-file MuchToDo/.env \
  muchtodo-backend:latest
```

#### With environment variables

```BASH
docker run -d \
  --name muchtodo-api \
  -p 8080:8080 \
  -e PORT=8080 \
  -e LOG_LEVEL=INFO \
  -e USE_SECRETS_MANAGER=false \
  -e MONGO_URI="mongodb://localhost:27017/much_todo_db" \
  -e JWT_SECRET_KEY="your-secret-key" \
  -e REDIS_ADDR="localhost:6379" \
  -e ENABLE_CACHE=true \
  muchtodo-backend:latest
```

#### With AWS Secrets Manager (production)

```BASH
docker run -d \
  --name muchtodo-api \
  -p 8080:8080 \
  -e USE_SECRETS_MANAGER=true \
  -e AWS_REGION=us-east-1 \
  -e JWT_SECRET_NAME=muchtodo-nonprod-jwt-secret \
  -e MONGODB_SECRET_NAME=muchtodo-nonprod-mongodb-credentials \
  -e REDIS_SECRET_NAME=muchtodo-nonprod-redis-credentials \
  muchtodo-backend:latest
```

### Health Check

The container includes a built-in health check that queries the `/health` endpoint:

```BASH
docker ps

docker inspect --format='{{json .State.Health}}' muchtodo-api | jq
```

### Logs

```BASH
docker logs -f muchtodo-api

docker logs --tail 100 muchtodo-api
```

## Docker Compose (Local Development)

The `MuchToDo/docker-compose.yaml` file sets up the complete local environment:

```BASH
cd MuchToDo

# Start all services (MongoDB, Redis, Mongo Express)
make dc-up
# or
docker-compose up -d

# Stop all services
make dc-down
# or
docker-compose down
```

## Building for Production

### Docker Hub

```BASH
docker login

docker tag muchtodo-backend:latest your-dockerhub-username/muchtodo-backend:v1.0.0

docker push your-dockerhub-username/muchtodo-backend:v1.0.0
```
