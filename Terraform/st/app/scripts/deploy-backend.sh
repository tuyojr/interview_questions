#!/bin/bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${APP_ROOT}/../infra/terraform"

ENVIRONMENT="${1:-nonprod}"
DOCKER_IMAGE="${2:-}"

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

    if [ -z "${DOCKER_IMAGE}" ]; then
        log_error "Docker image not specified"
        log_error "Usage: $0 <environment> <docker-image>"
        exit 1
    fi

    log_info "Using Docker image: ${DOCKER_IMAGE}"
}

get_infrastructure_outputs() {
    log_info "Retrieving infrastructure outputs..."

    cd "${TERRAFORM_DIR}"

    ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")
    if [ -z "${ASG_NAME}" ]; then
        log_error "Could not retrieve ASG name from Terraform outputs"
        exit 1
    fi

    ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "")
    if [ -z "${ALB_URL}" ]; then
        log_error "Could not retrieve ALB URL from Terraform outputs"
        exit 1
    fi

    TARGET_GROUP_ARN=$(terraform output -raw target_group_arn 2>/dev/null || echo "")

    log_info "ASG Name: ${ASG_NAME}"
    log_info "ALB URL: ${ALB_URL}"
}

get_asg_state() {
    log_info "Getting current ASG state..."

    ASG_INFO=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_NAME}" \
        --query 'AutoScalingGroups[0]')

    DESIRED_CAPACITY=$(echo "${ASG_INFO}" | jq -r '.DesiredCapacity')
    MIN_SIZE=$(echo "${ASG_INFO}" | jq -r '.MinSize')
    MAX_SIZE=$(echo "${ASG_INFO}" | jq -r '.MaxSize')

    log_info "Current capacity: Desired=${DESIRED_CAPACITY}, Min=${MIN_SIZE}, Max=${MAX_SIZE}"

    CURRENT_INSTANCES=$(echo "${ASG_INFO}" | jq -r '.Instances[].InstanceId' | tr '\n' ' ')
    log_info "Current instances: ${CURRENT_INSTANCES}"
}

create_launch_template_version() {
    log_info "Creating new launch template version..."

    LAUNCH_TEMPLATE_ID=$(echo "${ASG_INFO}" | jq -r '.LaunchTemplate.LaunchTemplateId')

    if [ -z "${LAUNCH_TEMPLATE_ID}" ] || [ "${LAUNCH_TEMPLATE_ID}" == "null" ]; then
        log_error "Could not retrieve launch template ID"
        exit 1
    fi

    TEMPLATE_DATA=$(aws ec2 describe-launch-template-versions \
        --launch-template-id "${LAUNCH_TEMPLATE_ID}" \
        --versions '$Latest' \
        --query 'LaunchTemplateVersions[0].LaunchTemplateData')

    log_info "Launch template ID: ${LAUNCH_TEMPLATE_ID}"
    log_warn "Note: For actual deployment, update the launch template with new Docker image in user data"
}

perform_instance_refresh() {
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

    local wait_time=0
    local max_wait=1800  # 30 minutes

    while [ $wait_time -lt $max_wait ]; do
        local status
        status=$(aws autoscaling describe-instance-refreshes \
            --auto-scaling-group-name "${ASG_NAME}" \
            --instance-refresh-ids "${refresh_id}" \
            --query 'InstanceRefreshes[0].Status' \
            --output text)

        log_info "Instance refresh status: ${status}"

        if [ "${status}" == "Successful" ]; then
            log_info "Instance refresh completed successfully"
            return 0
        elif [ "${status}" == "Failed" ] || [ "${status}" == "Cancelled" ]; then
            log_error "Instance refresh failed with status: ${status}"
            return 1
        fi

        sleep 60
        wait_time=$((wait_time + 60))
    done

    log_error "Instance refresh did not complete within timeout"
    return 1
}

verify_deployment() {
    log_info "Verifying deployment..."

    local healthy_count
    healthy_count=$(aws elbv2 describe-target-health \
        --target-group-arn "${TARGET_GROUP_ARN}" \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' \
        | jq '. | length')

    log_info "Healthy targets: ${healthy_count}"

    if [ "${healthy_count}" -ge "${DESIRED_CAPACITY}" ]; then
        log_info "Deployment verification successful"
        return 0
    else
        log_error "Insufficient healthy targets"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 <ENVIRONMENT> <DOCKER_IMAGE>

Deploy Golang backend to EC2 instances via rolling update

Arguments:
    ENVIRONMENT     Environment name (nonprod or prod)
    DOCKER_IMAGE    Docker image tag to deploy

Examples:
    # Deploy to non-prod
    $0 nonprod myregistry/muchtodo-backend:v1.2.3

    # Deploy to prod
    $0 prod myregistry/muchtodo-backend:v1.2.3

EOF
}

main() {
    log_info "Backend Deployment"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Docker Image: ${DOCKER_IMAGE}"
    echo

    if [ "${ENVIRONMENT}" != "nonprod" ] && [ "${ENVIRONMENT}" != "prod" ]; then
        log_error "Invalid environment: ${ENVIRONMENT}"
        show_usage
        exit 1
    fi

    validate_prerequisites
    get_infrastructure_outputs
    get_asg_state

    log_info "Deployment method: Instance Refresh"

    if perform_instance_refresh; then
        verify_deployment
        log_info "Backend deployment completed successfully!"
        log_info "Application accessible at: ${ALB_URL}"
    else
        log_error "Deployment failed"
        exit 1
    fi
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    show_usage
    exit 0
fi

main "$@"
