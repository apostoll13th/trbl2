#!/bin/bash
# =============================================================================
# DevOps Interview Tasks - Destroy Script
# =============================================================================
# Использование: ./scripts/destroy.sh
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
# Main
# =============================================================================

main() {
    echo "=============================================="
    echo " DevOps Interview Tasks - Destroy"
    echo "=============================================="
    echo

    # Load .env if exists
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
    else
        log_error ".env file not found"
        exit 1
    fi

    cd "$PROJECT_DIR/terraform"

    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        log_warn "No terraform state found. Nothing to destroy."
        exit 0
    fi

    log_warn "This will destroy all infrastructure!"
    echo
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Aborted."
        exit 0
    fi

    log_info "Destroying infrastructure..."
    terraform destroy -auto-approve

    # Clean up generated files
    rm -f "$PROJECT_DIR/ansible/inventory/hosts.yml"
    rm -f "$PROJECT_DIR/terraform/tfplan"

    log_info "Infrastructure destroyed successfully!"
}

main "$@"
