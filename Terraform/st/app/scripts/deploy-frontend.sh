#!/bin/bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${APP_ROOT}/frontend"
TERRAFORM_DIR="${APP_ROOT}/../infra/terraform"

ENVIRONMENT="${1:-nonprod}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

validate_prerequisites() {
    log_info "Validating prerequisites..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi

    if [ ! -d "${FRONTEND_DIR}/build" ]; then
        log_error "Build directory not found: ${FRONTEND_DIR}/build"
        log_error "Please run 'npm run build' first"
        exit 1
    fi

    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        exit 1
    fi
}

get_infrastructure_outputs() {
    log_info "Retrieving infrastructure outputs..."

    cd "${TERRAFORM_DIR}"

    BUCKET_NAME=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
    if [ -z "${BUCKET_NAME}" ]; then
        log_error "Could not retrieve S3 bucket name from Terraform outputs"
        exit 1
    fi

    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    if [ -z "${CLOUDFRONT_ID}" ]; then
        log_error "Could not retrieve CloudFront distribution ID from Terraform outputs"
        exit 1
    fi

    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")

    log_info "S3 Bucket: ${BUCKET_NAME}"
    log_info "CloudFront ID: ${CLOUDFRONT_ID}"
    log_info "CloudFront URL: ${CLOUDFRONT_URL}"
}

backup_current_version() {
    log_info "Creating backup of current version..."

    local backup_prefix="backups/$(date +%Y%m%d-%H%M%S)"

    if aws s3 ls "s3://${BUCKET_NAME}/" --recursive | grep -q .; then
        aws s3 sync \
            "s3://${BUCKET_NAME}/" \
            "s3://${BUCKET_NAME}/${backup_prefix}/" \
            --exclude "${backup_prefix}/*" \
            --quiet

        log_info "Backup created at: s3://${BUCKET_NAME}/${backup_prefix}/"
        echo "${backup_prefix}" > /tmp/frontend-backup-path
    else
        log_warn "No existing files to backup"
    fi
}

deploy_to_s3() {
    log_info "Deploying frontend to S3..."

    cd "${FRONTEND_DIR}"

    aws s3 sync \
        build/ \
        "s3://${BUCKET_NAME}/" \
        --delete \
        --cache-control "public, max-age=31536000" \
        --exclude "*.html" \
        --exclude "service-worker.js"

    aws s3 sync \
        build/ \
        "s3://${BUCKET_NAME}/" \
        --exclude "*" \
        --include "*.html" \
        --cache-control "no-cache, no-store, must-revalidate"

    if [ -f "build/service-worker.js" ]; then
        aws s3 cp \
            build/service-worker.js \
            "s3://${BUCKET_NAME}/service-worker.js" \
            --cache-control "no-cache, no-store, must-revalidate"
    fi

    log_info "Frontend deployed to S3 successfully"
}

invalidate_cloudfront() {
    log_info "Invalidating CloudFront cache..."

    local invalidation_id
    invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "${CLOUDFRONT_ID}" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)

    log_info "CloudFront invalidation created: ${invalidation_id}"
    log_info "Waiting for invalidation to complete..."

    local wait_time=0
    local max_wait=600  # 10 minutes

    while [ $wait_time -lt $max_wait ]; do
        local status
        status=$(aws cloudfront get-invalidation \
            --distribution-id "${CLOUDFRONT_ID}" \
            --id "${invalidation_id}" \
            --query 'Invalidation.Status' \
            --output text)

        if [ "${status}" == "Completed" ]; then
            log_info "CloudFront invalidation completed"
            return 0
        fi

        log_info "Invalidation status: ${status}. Waiting..."
        sleep 30
        wait_time=$((wait_time + 30))
    done

    log_warn "Invalidation did not complete within timeout. It may still be in progress."
}

verify_deployment() {
    log_info "Verifying deployment..."

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "${CLOUDFRONT_URL}/index.html")

    if [ "${status_code}" == "200" ]; then
        log_info "Deployment verification successful"
        log_info "Frontend is accessible at: ${CLOUDFRONT_URL}"
        return 0
    else
        log_error "Deployment verification failed. HTTP status: ${status_code}"
        return 1
    fi
}

rollback_deployment() {
    log_error "Deployment failed. Rolling back..."

    if [ -f /tmp/frontend-backup-path ]; then
        local backup_path
        backup_path=$(cat /tmp/frontend-backup-path)

        log_info "Restoring from backup: ${backup_path}"

        aws s3 sync \
            "s3://${BUCKET_NAME}/${backup_path}/" \
            "s3://${BUCKET_NAME}/" \
            --delete

        invalidate_cloudfront

        log_info "Rollback completed"
        rm -f /tmp/frontend-backup-path
    else
        log_error "No backup found. Manual recovery may be required."
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT]

Deploy React frontend to S3 and CloudFront

Arguments:
    ENVIRONMENT     Environment name (default: nonprod)

Examples:
    # Deploy to non-prod
    $0 nonprod

    # Deploy to prod
    $0 prod

EOF
}

main() {
    log_info "Frontend Deployment"
    log_info "Environment: ${ENVIRONMENT}"
    echo

    if [ "${ENVIRONMENT}" != "nonprod" ] && [ "${ENVIRONMENT}" != "prod" ]; then
        log_error "Invalid environment: ${ENVIRONMENT}"
        show_usage
        exit 1
    fi

    trap 'rollback_deployment' ERR

    validate_prerequisites
    get_infrastructure_outputs
    backup_current_version
    deploy_to_s3
    invalidate_cloudfront
    verify_deployment

    log_info "Frontend deployment completed successfully!"
    log_info "Access your application at: ${CLOUDFRONT_URL}"

    rm -f /tmp/frontend-backup-path
}

main "$@"
