#!/bin/bash
# =============================================================================
# DevOps Interview Tasks - Deploy Script
# =============================================================================
# Использование: ./scripts/deploy.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Check prerequisites
# =============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=0

    if ! command -v terraform &> /dev/null; then
        log_error "terraform is not installed"
        missing=1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        log_error "ansible is not installed"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        log_error "Please install missing prerequisites"
        exit 1
    fi

    log_info "All prerequisites are installed"
}

# =============================================================================
# Handle .env file
# =============================================================================

setup_env() {
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_warn ".env file not found"

        if [ -f "$PROJECT_DIR/.env.example" ]; then
            log_info "Creating .env from .env.example..."
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            log_warn "Please edit $PROJECT_DIR/.env with your VK Cloud credentials"
            log_info "Then run this script again"
            exit 0
        else
            log_error ".env.example not found. Cannot proceed."
            exit 1
        fi
    fi

    # Validate .env has real values
    source "$PROJECT_DIR/.env"

    if [ -z "$TF_VAR_vkcs_username" ] || [ "$TF_VAR_vkcs_username" = "user@example.com" ]; then
        log_error "Please set TF_VAR_vkcs_username in .env"
        exit 1
    fi

    if [ -z "$TF_VAR_vkcs_password" ] || [ "$TF_VAR_vkcs_password" = "your-password" ]; then
        log_error "Please set TF_VAR_vkcs_password in .env"
        exit 1
    fi

    if [ -z "$TF_VAR_vkcs_project_id" ] || [ "$TF_VAR_vkcs_project_id" = "your-project-id" ]; then
        log_error "Please set TF_VAR_vkcs_project_id in .env"
        exit 1
    fi

    log_info "Credentials loaded from .env"
}

# =============================================================================
# Check SSH key
# =============================================================================

check_ssh_key() {
    local ssh_key="${TF_VAR_ssh_public_key_path:-$HOME/.ssh/id_rsa.pub}"
    ssh_key="${ssh_key/#\~/$HOME}"

    if [ ! -f "$ssh_key" ]; then
        log_warn "SSH public key not found at $ssh_key"
        log_info "Generating new SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "${ssh_key%.pub}" -N "" -q
        log_info "SSH key generated: ${ssh_key%.pub}"
    fi

    log_info "Using SSH key: $ssh_key"
}

# =============================================================================
# Terraform
# =============================================================================

run_terraform() {
    log_info "Running Terraform..."

    cd "$PROJECT_DIR/terraform"

    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform..."
        terraform init
    fi

    log_info "Planning infrastructure..."
    terraform plan -out=tfplan

    log_info "Applying infrastructure..."
    terraform apply tfplan

    # Get outputs
    VM_IP=$(terraform output -raw vm_ip)
    log_info "VM created with IP: $VM_IP"

    cd "$PROJECT_DIR"
}

# =============================================================================
# Wait for SSH
# =============================================================================

wait_for_ssh() {
    local vm_ip="$1"
    local max_attempts=30
    local attempt=1

    log_info "Waiting for SSH to become available on $vm_ip..."

    while [ $attempt -le $max_attempts ]; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ubuntu@"$vm_ip" "echo 'SSH OK'" &>/dev/null; then
            log_info "SSH is available!"
            return 0
        fi
        log_info "Attempt $attempt/$max_attempts - waiting..."
        sleep 10
        ((attempt++))
    done

    log_error "SSH did not become available in time"
    return 1
}

# =============================================================================
# Ansible
# =============================================================================

run_ansible() {
    log_info "Running Ansible playbook..."

    cd "$PROJECT_DIR/ansible"

    # Get VM IP from terraform
    local vm_ip
    vm_ip=$(cd "$PROJECT_DIR/terraform" && terraform output -raw vm_ip)

    # Wait for SSH
    wait_for_ssh "$vm_ip"

    # Run playbook
    ansible-playbook playbooks/setup-all.yml -v

    cd "$PROJECT_DIR"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "=============================================="
    echo " DevOps Interview Tasks - Deploy"
    echo "=============================================="
    echo

    check_prerequisites
    setup_env
    check_ssh_key
    run_terraform
    run_ansible

    echo
    echo "=============================================="
    log_info "Deployment completed successfully!"
    echo "=============================================="
    echo

    cd "$PROJECT_DIR/terraform"
    echo "VM IP: $(terraform output -raw vm_ip)"
    echo "SSH:   $(terraform output -raw ssh_command)"
    echo
    echo "=============================================="
    echo " Interview Tasks:"
    echo "=============================================="
    echo "1. Docker:   curl localhost:8080 не работает"
    echo "2. DNS:      curl google.com не работает"
    echo "3. K8s:      kubectl -n interview get pods (CrashLoopBackOff)"
    echo "4. GitLab:   gitlab-runner verify (docker недоступен)"
    echo "=============================================="
}

main "$@"
