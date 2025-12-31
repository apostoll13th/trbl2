#!/bin/bash
# =============================================================================
# DevOps Interview Tasks - Deploy Script
# =============================================================================
# Использование:
#   ./scripts/deploy.sh              - Запустить все задачи
#   ./scripts/deploy.sh list         - Показать список задач
#   ./scripts/deploy.sh docker       - Запустить только Docker задачу
#   ./scripts/deploy.sh docker,k8s   - Запустить несколько задач
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Available tasks (compatible with bash 3.x on macOS)
# =============================================================================

TASK_NAMES="docker k8s gitlab postgres disk ssl nginx dns"

get_task_description() {
    case "$1" in
        docker)   echo "Docker контейнер не отвечает на порту 8080" ;;
        k8s)      echo "Kubernetes Pod в CrashLoopBackOff" ;;
        gitlab)   echo "GitLab Runner не может запустить jobs" ;;
        postgres) echo "PostgreSQL не принимает подключения" ;;
        disk)     echo "Диск заполнен, но du не показывает файлы" ;;
        ssl)      echo "HTTPS не работает (проблема с сертификатом)" ;;
        nginx)    echo "Nginx systemd сервис не стартует" ;;
        dns)      echo "DNS не работает, curl по домену падает" ;;
        *)        echo "" ;;
    esac
}

is_valid_task() {
    local task="$1"
    for t in $TASK_NAMES; do
        if [ "$t" = "$task" ]; then
            return 0
        fi
    done
    return 1
}

# =============================================================================
# Show task list
# =============================================================================

show_tasks() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${BLUE}DevOps Interview Tasks - Список задач${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"

    local i=1
    for task in $TASK_NAMES; do
        local desc=$(get_task_description "$task")
        printf "${CYAN}║${NC}  ${GREEN}%-2s${NC}. ${YELLOW}%-10s${NC} - %-40s ${CYAN}║${NC}\n" "$i" "$task" "$desc"
        i=$((i + 1))
    done

    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Примеры запуска:${NC}                                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}./scripts/deploy.sh${NC}              - все задачи           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}./scripts/deploy.sh docker${NC}       - только Docker        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}./scripts/deploy.sh k8s${NC}          - только Kubernetes    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}./scripts/deploy.sh docker,k8s${NC}   - Docker + Kubernetes  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}./scripts/deploy.sh list${NC}         - показать этот список ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# =============================================================================
# Validate tasks
# =============================================================================

validate_tasks() {
    local input="$1"
    local valid_tasks=""

    # Split by comma
    local OLD_IFS="$IFS"
    IFS=','
    for task in $input; do
        IFS="$OLD_IFS"
        task=$(echo "$task" | tr -d ' ')
        if ! is_valid_task "$task"; then
            log_error "Unknown task: $task"
            echo "Available tasks: $TASK_NAMES"
            exit 1
        fi
        if [ -n "$valid_tasks" ]; then
            valid_tasks="$valid_tasks,$task"
        else
            valid_tasks="$task"
        fi
        IFS=','
    done
    IFS="$OLD_IFS"

    echo "$valid_tasks"
}

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
        attempt=$((attempt + 1))
    done

    log_error "SSH did not become available in time"
    return 1
}

# =============================================================================
# Ansible
# =============================================================================

run_ansible() {
    local selected_tasks="$1"

    log_info "Running Ansible playbook..."

    cd "$PROJECT_DIR/ansible"

    # Get VM IP from terraform
    local vm_ip
    vm_ip=$(cd "$PROJECT_DIR/terraform" && terraform output -raw vm_ip)

    # Wait for VM to boot (cloud-init takes time)
    log_info "Waiting 60 seconds for VM to boot..."
    sleep 60

    # Wait for SSH
    wait_for_ssh "$vm_ip"

    # Build ansible command
    local ansible_cmd="ansible-playbook playbooks/setup-all.yml -v"

    if [ -n "$selected_tasks" ]; then
        # Always include common role for dependencies
        ansible_cmd="$ansible_cmd --tags common,$selected_tasks"
        log_info "Running tasks: common,$selected_tasks"
    else
        log_info "Running all tasks"
    fi

    # Run playbook
    $ansible_cmd

    cd "$PROJECT_DIR"
}

# =============================================================================
# Show completion message
# =============================================================================

show_completion() {
    local selected_tasks="$1"

    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}Deployment completed successfully!${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"

    cd "$PROJECT_DIR/terraform"
    local vm_ip=$(terraform output -raw vm_ip)
    local ssh_cmd=$(terraform output -raw ssh_command)

    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}VM IP:${NC}  $vm_ip                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}SSH:${NC}    $ssh_cmd                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Deployed tasks:${NC}                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"

    if [ -n "$selected_tasks" ]; then
        local OLD_IFS="$IFS"
        IFS=','
        for task in $selected_tasks; do
            IFS="$OLD_IFS"
            local desc=$(get_task_description "$task")
            printf "${CYAN}║${NC}    ${GREEN}✓${NC} ${YELLOW}%-10s${NC} - %-42s ${CYAN}║${NC}\n" "$task" "$desc"
            IFS=','
        done
        IFS="$OLD_IFS"
    else
        for task in $TASK_NAMES; do
            local desc=$(get_task_description "$task")
            printf "${CYAN}║${NC}    ${GREEN}✓${NC} ${YELLOW}%-10s${NC} - %-42s ${CYAN}║${NC}\n" "$task" "$desc"
        done
    fi

    echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo

    cd "$PROJECT_DIR"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local selected_tasks=""

    # Handle arguments
    case "${1:-}" in
        list|--list|-l)
            show_tasks
            exit 0
            ;;
        help|--help|-h)
            show_tasks
            exit 0
            ;;
        "")
            # No argument - run all tasks
            selected_tasks=""
            ;;
        *)
            # Validate and set selected tasks
            selected_tasks=$(validate_tasks "$1")
            ;;
    esac

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${BLUE}DevOps Interview Tasks - Deploy${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo

    check_prerequisites
    setup_env
    check_ssh_key
    run_terraform
    run_ansible "$selected_tasks"
    show_completion "$selected_tasks"
}

main "$@"
