#!/bin/bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${APP_ROOT}/../infra/terraform"
ENVIRONMENT="${1:-}"
COMPONENT="${2:-}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

get_infrastructure_outputs() {
    log_info "Retrieving infrastructure outputs..."

    cd "${TERRAFORM_DIR}"

    BUCKET_NAME=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")
    LAUNCH_TEMPLATE_ID=$(terraform output -raw launch_template_id 2>/dev/null || echo "")

    log_info "Infrastructure outputs retrieved"
}

list_frontend_backups() {
    log_info "Listing available frontend backups..."

    if [ -z "${BUCKET_NAME}" ]; then
        log_error "S3 bucket name not available"
        return 1
    fi

    local backups
    backups=$(aws s3 ls "s3://${BUCKET_NAME}/backups/" --recursive \
        | awk '{print $4}' \
        | grep "backups/" \
        | cut -d'/' -f2 \
        | sort -u \
        | tail -5)

    if [ -z "${backups}" ]; then
        log_error "No backups found"
        return 1
    fi

    echo
    echo "Available backups:"
    echo "${backups}" | nl
    echo

    return 0
}

rollback_frontend() {
    log_info "Rolling back frontend deployment..."

    if ! list_frontend_backups; then
        log_error "Cannot proceed with rollback - no backups available"
        return 1
    fi

    echo -n "Enter backup number to restore (or 'c' to cancel): "
    read -r selection

    if [ "${selection}" == "c" ] || [ "${selection}" == "C" ]; then
        log_info "Rollback cancelled"
        return 0
    fi

    local backup_path
    backup_path=$(aws s3 ls "s3://${BUCKET_NAME}/backups/" --recursive \
        | awk '{print $4}' \
        | grep "backups/" \
        | cut -d'/' -f2 \
        | sort -u \
        | tail -5 \
        | sed -n "${selection}p")

    if [ -z "${backup_path}" ]; then
        log_error "Invalid selection"
        return 1
    fi

    log_info "Restoring from backup: ${backup_path}"

    echo -n "Are you sure you want to rollback? (yes/no): "
    read -r confirm

    if [ "${confirm}" != "yes" ]; then
        log_info "Rollback cancelled"
        return 0
    fi

    aws s3 sync \
        "s3://${BUCKET_NAME}/backups/${backup_path}/" \
        "s3://${BUCKET_NAME}/" \
        --delete \
        --exclude "backups/*"

    log_info "Files restored from backup"

    log_info "Invalidating CloudFront cache..."

    local invalidation_id
    invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "${CLOUDFRONT_ID}" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)

    log_info "CloudFront invalidation created: ${invalidation_id}"

    log_info "Waiting for invalidation to complete (this may take a few minutes)..."
    aws cloudfront wait invalidation-completed \
        --distribution-id "${CLOUDFRONT_ID}" \
        --id "${invalidation_id}" || true

    log_info "Frontend rollback completed successfully"

    local cloudfront_url
    cloudfront_url=$(cd "${TERRAFORM_DIR}" && terraform output -raw cloudfront_url 2>/dev/null || echo "")
    log_info "Frontend accessible at: ${cloudfront_url}"

    return 0
}

list_launch_template_versions() {
    log_info "Listing available launch template versions..."

    if [ -z "${LAUNCH_TEMPLATE_ID}" ]; then
        log_error "Launch template ID not available"
        return 1
    fi

    local versions
    versions=$(aws ec2 describe-launch-template-versions \
        --launch-template-id "${LAUNCH_TEMPLATE_ID}" \
        --query 'LaunchTemplateVersions[*].[VersionNumber,CreateTime,VersionDescription]' \
        --output text \
        | sort -rn \
        | head -10)

    if [ -z "${versions}" ]; then
        log_error "No launch template versions found"
        return 1
    fi

    echo
    echo "Available versions:"
    echo "${versions}" | nl
    echo

    return 0
}

rollback_backend() {
    log_info "Rolling back backend deployment..."

    if ! list_launch_template_versions; then
        log_error "Cannot proceed with rollback"
        return 1
    fi

    local current_version
    current_version=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_NAME}" \
        --query 'AutoScalingGroups[0].LaunchTemplate.Version' \
        --output text)

    log_info "Current launch template version: ${current_version}"

    echo -n "Enter version number to rollback to (or 'c' to cancel): "
    read -r selection

    if [ "${selection}" == "c" ] || [ "${selection}" == "C" ]; then
        log_info "Rollback cancelled"
        return 0
    fi

    if ! aws ec2 describe-launch-template-versions \
        --launch-template-id "${LAUNCH_TEMPLATE_ID}" \
        --versions "${selection}" &>/dev/null; then
        log_error "Invalid version number"
        return 1
    fi

    log_info "Rolling back to version: ${selection}"

    echo -n "Are you sure you want to rollback? (yes/no): "
    read -r confirm

    if [ "${confirm}" != "yes" ]; then
        log_info "Rollback cancelled"
        return 0
    fi

    log_info "Updating Auto Scaling Group..."

    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "${ASG_NAME}" \
        --launch-template "LaunchTemplateId=${LAUNCH_TEMPLATE_ID},Version=${selection}"

    log_info "ASG updated to use version ${selection}"

    log_info "Starting instance refresh..."

    local refresh_id
    refresh_id=$(aws autoscaling start-instance-refresh \
        --auto-scaling-group-name "${ASG_NAME}" \
        --preferences '{
            "MinHealthyPercentage": 50,
            "InstanceWarmup": 300
        }' \
        --query 'InstanceRefreshId' \
        --output text)

    log_info "Instance refresh started: ${refresh_id}"

    log_info "Monitoring instance refresh progress..."

    local wait_time=0
    local max_wait=1800  # 30 minutes

    while [ $wait_time -lt $max_wait ]; do
        local status
        local percentage

        status=$(aws autoscaling describe-instance-refreshes \
            --auto-scaling-group-name "${ASG_NAME}" \
            --instance-refresh-ids "${refresh_id}" \
            --query 'InstanceRefreshes[0].Status' \
            --output text)

        percentage=$(aws autoscaling describe-instance-refreshes \
            --auto-scaling-group-name "${ASG_NAME}" \
            --instance-refresh-ids "${refresh_id}" \
            --query 'InstanceRefreshes[0].PercentageComplete' \
            --output text)

        log_info "Instance refresh: ${status} (${percentage}% complete)"

        if [ "${status}" == "Successful" ]; then
            log_info "Instance refresh completed successfully"
            break
        elif [ "${status}" == "Failed" ] || [ "${status}" == "Cancelled" ]; then
            log_error "Instance refresh failed with status: ${status}"
            return 1
        fi

        sleep 60
        wait_time=$((wait_time + 60))
    done

    if [ $wait_time -ge $max_wait ]; then
        log_error "Instance refresh did not complete within timeout"
        return 1
    fi

    log_info "Backend rollback completed successfully"

    local alb_url
    alb_url=$(cd "${TERRAFORM_DIR}" && terraform output -raw alb_url 2>/dev/null || echo "")
    log_info "Backend accessible at: ${alb_url}"

    return 0
}

show_usage() {
    cat << EOF
Usage: $0 <ENVIRONMENT> <COMPONENT>

Rollback deployment to a previous version

Arguments:
    ENVIRONMENT     Environment name (nonprod or prod)
    COMPONENT       Component to rollback (frontend or backend)

Examples:
    # Rollback frontend
    $0 nonprod frontend

    # Rollback backend
    $0 nonprod backend

    # Rollback production frontend
    $0 prod frontend

EOF
}

main() {
    if [ -z "${ENVIRONMENT}" ] || [ -z "${COMPONENT}" ]; then
        log_error "Missing required arguments"
        show_usage
        exit 1
    fi

    if [ "${ENVIRONMENT}" != "nonprod" ] && [ "${ENVIRONMENT}" != "prod" ]; then
        log_error "Invalid environment: ${ENVIRONMENT}"
        show_usage
        exit 1
    fi

    if [ "${COMPONENT}" != "frontend" ] && [ "${COMPONENT}" != "backend" ]; then
        log_error "Invalid component: ${COMPONENT}"
        show_usage
        exit 1
    fi

    echo
    log_warn "==================== ROLLBACK WARNING ===================="
    log_warn "Environment: ${ENVIRONMENT}"
    log_warn "Component:   ${COMPONENT}"
    log_warn "=========================================================="
    echo

    get_infrastructure_outputs

    case "${COMPONENT}" in
        frontend)
            rollback_frontend
            ;;
        backend)
            rollback_backend
            ;;
    esac

    if [ $? -eq 0 ]; then
        log_info "Rollback completed successfully"
        exit 0
    else
        log_error "Rollback failed"
        exit 1
    fi
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    show_usage
    exit 0
fi

main "$@"
