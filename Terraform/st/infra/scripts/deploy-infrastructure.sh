#!/bin/bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${INFRA_ROOT}/terraform"
ENVIRONMENT="${ENVIRONMENT:-nonprod}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
ACTION="${1:-apply}"

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

    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform >= 1.0"
        exit 1
    fi

    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: ${tf_version}"

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi

    local aws_identity
    aws_identity=$(aws sts get-caller-identity)
    log_info "AWS Account: $(echo "${aws_identity}" | jq -r '.Account')"
    log_info "AWS User: $(echo "${aws_identity}" | jq -r '.Arn')"

    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        exit 1
    fi

    if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found. Using terraform.tfvars.example as reference."
        log_warn "Please create terraform.tfvars with your configuration."

        if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars.example" ]; then
            log_error "terraform.tfvars.example not found either."
            exit 1
        fi
    fi
}

validate_backend() {
    log_info "Validating S3 backend..."

    local backend_bucket
    backend_bucket=$(grep -A 5 'backend "s3"' "${TERRAFORM_DIR}/main.tf" | grep 'bucket' | cut -d'"' -f2)

    if [ -z "${backend_bucket}" ]; then
        log_error "Could not extract S3 backend bucket from main.tf"
        exit 1
    fi

    if ! aws s3 ls "s3://${backend_bucket}" &> /dev/null; then
        log_error "S3 backend bucket '${backend_bucket}' does not exist or is not accessible"
        log_error "Please create the bucket first or check your AWS permissions"
        exit 1
    fi

    log_info "S3 backend bucket '${backend_bucket}' is accessible"
}

terraform_init() {
    log_info "Initializing Terraform..."
    cd "${TERRAFORM_DIR}"

    if terraform init -upgrade; then
        log_info "Terraform initialized successfully"
    else
        log_error "Terraform initialization failed"
        exit 1
    fi
}

terraform_validate() {
    log_info "Validating Terraform configuration..."
    cd "${TERRAFORM_DIR}"

    if terraform validate; then
        log_info "Terraform configuration is valid"
    else
        log_error "Terraform validation failed"
        exit 1
    fi
}

terraform_fmt() {
    log_info "Formatting Terraform files..."
    cd "${TERRAFORM_DIR}"

    if terraform fmt -recursive -check; then
        log_info "All Terraform files are properly formatted"
    else
        log_warn "Some files need formatting. Running terraform fmt..."
        terraform fmt -recursive
        log_info "Files formatted successfully"
    fi
}

terraform_plan() {
    log_info "Running Terraform plan..."
    cd "${TERRAFORM_DIR}"

    local plan_file="${TERRAFORM_DIR}/tfplan"

    if terraform plan -out="${plan_file}"; then
        log_info "Terraform plan completed successfully"
        log_info "Plan saved to: ${plan_file}"
        return 0
    else
        log_error "Terraform plan failed"
        exit 1
    fi
}

terraform_apply() {
    log_info "Applying Terraform configuration..."
    cd "${TERRAFORM_DIR}"

    local plan_file="${TERRAFORM_DIR}/tfplan"

    if [ ! -f "${plan_file}" ]; then
        log_warn "No plan file found. Running plan first..."
        terraform_plan
    fi

    if [ "${AUTO_APPROVE}" != "true" ]; then
        log_warn "This will apply changes to your infrastructure."
        read -p "Do you want to continue? (yes/no): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Apply cancelled by user"
            exit 0
        fi
    fi

    if terraform apply "${plan_file}"; then
        log_info "Terraform apply completed successfully"
        rm -f "${plan_file}"
    else
        log_error "Terraform apply failed"
        exit 1
    fi
}

terraform_destroy() {
    log_error "DANGER: This will destroy all infrastructure!"
    log_error "Environment: ${ENVIRONMENT}"

    cd "${TERRAFORM_DIR}"

    read -p "Type 'destroy' to confirm: " -r
    echo
    if [[ ! $REPLY == "destroy" ]]; then
        log_info "Destroy cancelled"
        exit 0
    fi

    log_warn "Starting infrastructure destruction..."

    if terraform destroy; then
        log_info "Infrastructure destroyed successfully"
    else
        log_error "Terraform destroy failed"
        exit 1
    fi
}

terraform_output() {
    log_info "Retrieving Terraform outputs..."
    cd "${TERRAFORM_DIR}"

    terraform output
}

show_usage() {
    cat << EOF
Usage: $0 [ACTION]

Infrastructure deployment script for MuchToDo

Actions:
    plan        Run terraform plan (default if no action specified)
    apply       Apply terraform changes
    destroy     Destroy all infrastructure (requires confirmation)
    output      Show terraform outputs
    validate    Validate configuration only
    fmt         Format terraform files

Environment Variables:
    ENVIRONMENT     Environment name (default: nonprod)
    AUTO_APPROVE    Skip confirmation prompts (default: false)

Examples:
    # Plan changes
    $0 plan

    # Apply with auto-approval
    AUTO_APPROVE=true $0 apply

    # Destroy infrastructure for specific environment
    ENVIRONMENT=nonprod $0 destroy

EOF
}

main() {
    log_info "MuchToDo Infrastructure Deployment"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Action: ${ACTION}"
    echo

    case "${ACTION}" in
        plan)
            validate_prerequisites
            validate_backend
            terraform_init
            terraform_fmt
            terraform_validate
            terraform_plan
            ;;
        apply)
            validate_prerequisites
            validate_backend
            terraform_init
            terraform_fmt
            terraform_validate
            terraform_plan
            terraform_apply
            terraform_output
            ;;
        destroy)
            validate_prerequisites
            validate_backend
            terraform_init
            terraform_destroy
            ;;
        output)
            validate_prerequisites
            terraform_output
            ;;
        validate)
            validate_prerequisites
            terraform_init
            terraform_fmt
            terraform_validate
            log_info "Configuration is valid!"
            ;;
        fmt)
            terraform_fmt
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown action: ${ACTION}"
            show_usage
            exit 1
            ;;
    esac

    log_info "Done!"
}

main "$@"
