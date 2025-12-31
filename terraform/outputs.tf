# =============================================================================
# outputs.tf - Выходные значения
# =============================================================================
# Outputs - значения, которые Terraform выводит после apply
# Используются для:
# 1. Показать важную информацию пользователю
# 2. Передать данные в скрипты или другие модули
# 3. Интеграция с Ansible, CI/CD и т.д.
# =============================================================================

output "vm_ip" {
  description = "Public IP address of the VM"
  value       = vkcs_compute_instance.interview.access_ip_v4
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ubuntu@${vkcs_compute_instance.interview.access_ip_v4}"
}

output "vm_name" {
  description = "Name of the VM"
  value       = vkcs_compute_instance.interview.name
}

output "vm_id" {
  description = "ID of the VM instance"
  value       = vkcs_compute_instance.interview.id
}

# -----------------------------------------------------------------------------
# Как использовать outputs:
# -----------------------------------------------------------------------------
#
# После terraform apply:
#   terraform output           # показать все outputs
#   terraform output vm_ip     # показать только IP
#   terraform output -raw vm_ip  # без кавычек (для скриптов)
#   terraform output -json     # в формате JSON
#
# В скриптах:
#   VM_IP=$(terraform output -raw vm_ip)
#   ssh ubuntu@$VM_IP
# -----------------------------------------------------------------------------
