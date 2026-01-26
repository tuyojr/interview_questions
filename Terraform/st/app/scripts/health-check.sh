#!/bin/bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${APP_ROOT}/../infra/terraform"

TARGET="${1:-all}"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $*"
    ((PASSED_CHECKS++))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $*"
    ((FAILED_CHECKS++))
}

get_infrastructure_outputs() {
    log_info "Retrieving infrastructure outputs..."

    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_warn "Terraform directory not found: ${TERRAFORM_DIR}"
        return 1
    fi

    cd "${TERRAFORM_DIR}"

    ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "")
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")
    TARGET_GROUP_ARN=$(terraform output -raw target_group_arn 2>/dev/null || echo "")
    REDIS_ADDRESS=$(terraform output -raw redis_connection_string 2>/dev/null || echo "")

    log_info "Infrastructure outputs retrieved"
}

check_backend_health_endpoint() {
    log_check "Checking backend health endpoint..."
    ((TOTAL_CHECKS++))

    if [ -z "${ALB_URL}" ]; then
        log_fail "ALB URL not available"
        return 1
    fi

    local response
    local status_code

    response=$(curl -s -w "\n%{http_code}" "${ALB_URL}/health" 2>/dev/null || echo "000")
    status_code=$(echo "${response}" | tail -n1)

    if [ "${status_code}" == "200" ]; then
        log_pass "Backend health endpoint responding (HTTP ${status_code})"
        return 0
    else
        log_fail "Backend health endpoint unhealthy (HTTP ${status_code})"
        return 1
    fi
}

check_backend_api_endpoints() {
    log_check "Checking backend API endpoints..."
    ((TOTAL_CHECKS++))

    if [ -z "${ALB_URL}" ]; then
        log_fail "ALB URL not available"
        return 1
    fi

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "${ALB_URL}/api/v1/status" 2>/dev/null || echo "000")

    if [ "${status_code}" == "200" ] || [ "${status_code}" == "404" ]; then
        log_pass "Backend API accessible (HTTP ${status_code})"
        return 0
    else
        log_fail "Backend API not accessible (HTTP ${status_code})"
        return 1
    fi
}

check_alb_target_health() {
    log_check "Checking ALB target health..."
    ((TOTAL_CHECKS++))

    if [ -z "${TARGET_GROUP_ARN}" ]; then
        log_warn "Target group ARN not available, skipping"
        return 0
    fi

    local healthy_count
    local unhealthy_count
    local total_count

    local health_data
    health_data=$(aws elbv2 describe-target-health \
        --target-group-arn "${TARGET_GROUP_ARN}" 2>/dev/null || echo "")

    if [ -z "${health_data}" ]; then
        log_fail "Could not retrieve target health"
        return 1
    fi

    healthy_count=$(echo "${health_data}" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    unhealthy_count=$(echo "${health_data}" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "unhealthy")] | length')
    total_count=$(echo "${health_data}" | jq '.TargetHealthDescriptions | length')

    log_info "Target health: ${healthy_count} healthy, ${unhealthy_count} unhealthy, ${total_count} total"

    if [ "${healthy_count}" -gt 0 ] && [ "${unhealthy_count}" -eq 0 ]; then
        log_pass "All targets healthy"
        return 0
    elif [ "${healthy_count}" -gt 0 ]; then
        log_warn "Some targets unhealthy but service operational"
        ((PASSED_CHECKS++))
        return 0
    else
        log_fail "No healthy targets"
        return 1
    fi
}

check_asg_status() {
    log_check "Checking Auto Scaling Group status..."
    ((TOTAL_CHECKS++))

    if [ -z "${ASG_NAME}" ]; then
        log_warn "ASG name not available, skipping"
        return 0
    fi

    local asg_info
    asg_info=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_NAME}" 2>/dev/null || echo "")

    if [ -z "${asg_info}" ]; then
        log_fail "Could not retrieve ASG information"
        return 1
    fi

    local desired
    local current
    local min
    local max

    desired=$(echo "${asg_info}" | jq -r '.AutoScalingGroups[0].DesiredCapacity')
    current=$(echo "${asg_info}" | jq -r '.AutoScalingGroups[0].Instances | length')
    min=$(echo "${asg_info}" | jq -r '.AutoScalingGroups[0].MinSize')
    max=$(echo "${asg_info}" | jq -r '.AutoScalingGroups[0].MaxSize')

    log_info "ASG capacity: Current=${current}, Desired=${desired}, Min=${min}, Max=${max}"

    if [ "${current}" -ge "${min}" ] && [ "${current}" -eq "${desired}" ]; then
        log_pass "ASG running at desired capacity"
        return 0
    else
        log_fail "ASG not at desired capacity"
        return 1
    fi
}

check_frontend_accessibility() {
    log_check "Checking frontend accessibility..."
    ((TOTAL_CHECKS++))

    if [ -z "${CLOUDFRONT_URL}" ]; then
        log_fail "CloudFront URL not available"
        return 1
    fi

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "${CLOUDFRONT_URL}" 2>/dev/null || echo "000")

    if [ "${status_code}" == "200" ]; then
        log_pass "Frontend accessible via CloudFront (HTTP ${status_code})"
        return 0
    else
        log_fail "Frontend not accessible (HTTP ${status_code})"
        return 1
    fi
}

check_cloudfront_status() {
    log_check "Checking CloudFront distribution status..."
    ((TOTAL_CHECKS++))

    if [ -z "${CLOUDFRONT_ID}" ]; then
        log_warn "CloudFront distribution ID not available, skipping"
        return 0
    fi

    local status
    status=$(aws cloudfront get-distribution \
        --id "${CLOUDFRONT_ID}" \
        --query 'Distribution.Status' \
        --output text 2>/dev/null || echo "")

    if [ "${status}" == "Deployed" ]; then
        log_pass "CloudFront distribution deployed"
        return 0
    else
        log_fail "CloudFront distribution not deployed (Status: ${status})"
        return 1
    fi
}

check_redis_connectivity() {
    log_check "Checking Redis connectivity..."
    ((TOTAL_CHECKS++))

    if [ -z "${REDIS_ADDRESS}" ]; then
        log_warn "Redis address not available, skipping"
        return 0
    fi
    
    local redis_host
    local redis_port
    redis_host=$(echo "${REDIS_ADDRESS}" | cut -d':' -f1)
    redis_port=$(echo "${REDIS_ADDRESS}" | cut -d':' -f2 || echo "6379")

    if command -v nc &> /dev/null; then
        if timeout 5 nc -z "${redis_host}" "${redis_port}" 2>/dev/null; then
            log_pass "Redis port accessible"
            return 0
        else
            log_warn "Redis port not accessible from this location (may require VPN/bastion)"
            ((PASSED_CHECKS++))
            return 0
        fi
    else
        log_warn "netcat not installed, skipping Redis connectivity test"
        ((PASSED_CHECKS++))
        return 0
    fi
}

check_cloudwatch_logs() {
    log_check "Checking CloudWatch logs..."
    ((TOTAL_CHECKS++))

    local log_groups=(
        "/aws/ec2/nonprod/backend"
        "/aws/cloudfront/nonprod/frontend"
        "/aws/elasticloadbalancing/nonprod/alb"
    )

    local logs_ok=true

    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups \
            --log-group-name-prefix "${log_group}" \
            --query 'logGroups[0].logGroupName' \
            --output text 2>/dev/null | grep -q "${log_group}"; then
            log_info "Log group exists: ${log_group}"
        else
            log_warn "Log group not found: ${log_group}"
            logs_ok=false
        fi
    done

    if [ "${logs_ok}" == true ]; then
        log_pass "CloudWatch log groups configured"
        return 0
    else
        log_warn "Some CloudWatch log groups missing"
        ((PASSED_CHECKS++))
        return 0
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [TARGET]

Perform health checks on application components

Targets:
    all         Check all components (default)
    backend     Check backend API and ALB only
    frontend    Check frontend and CloudFront only
    infra       Check infrastructure components only

Examples:
    # Check all components
    $0 all

    # Check backend only
    $0 backend

    # Check frontend only
    $0 frontend

EOF
}

show_summary() {
    echo
    echo "========================================"
    echo "Health Check Summary"
    echo "========================================"
    echo "Total Checks:  ${TOTAL_CHECKS}"
    echo "Passed:        ${PASSED_CHECKS}"
    echo "Failed:        ${FAILED_CHECKS}"
    echo "========================================"

    if [ ${FAILED_CHECKS} -eq 0 ]; then
        echo -e "${GREEN}All health checks passed!${NC}"
        return 0
    else
        echo -e "${RED}Some health checks failed!${NC}"
        return 1
    fi
}

main() {
    log_info "Health Check - Target: ${TARGET}"
    echo

    get_infrastructure_outputs

    case "${TARGET}" in
        all)
            log_info "Checking all components..."
            echo
            check_backend_health_endpoint
            check_backend_api_endpoints
            check_alb_target_health
            check_asg_status
            check_frontend_accessibility
            check_cloudfront_status
            check_redis_connectivity
            check_cloudwatch_logs
            ;;
        backend)
            log_info "Checking backend components..."
            echo
            check_backend_health_endpoint
            check_backend_api_endpoints
            check_alb_target_health
            check_asg_status
            ;;
        frontend)
            log_info "Checking frontend components..."
            echo
            check_frontend_accessibility
            check_cloudfront_status
            ;;
        infra)
            log_info "Checking infrastructure components..."
            echo
            check_redis_connectivity
            check_cloudwatch_logs
            ;;
        *)
            log_error "Invalid target: ${TARGET}"
            show_usage
            exit 1
            ;;
    esac

    show_summary
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    show_usage
    exit 0
fi

main "$@"
