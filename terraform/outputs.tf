# =============================================================================
# outputs.tf - Выходные значения
# =============================================================================
# Outputs - это значения, которые Terraform выводит после apply
# Используются для:
# 1. Показать важную информацию пользователю
# 2. Передать данные в другие модули или скрипты
# 3. Сохранить в state для последующего использования
# =============================================================================

output "vm_ip" {
  # description - описание что это за значение
  description = "Public IP address of the VM"

  # value - само значение
  # Берём атрибут address из ресурса floating IP
  # Формат: <тип_ресурса>.<имя>.<атрибут>
  value = vkcs_networking_floatingip.interview.address

  # После terraform apply будет выведено:
  # vm_ip = "89.208.xxx.xxx"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"

  # Интерполяция строк: ${...} подставляет значение
  # ubuntu - стандартный пользователь в Ubuntu образах VK Cloud
  value = "ssh ubuntu@${vkcs_networking_floatingip.interview.address}"

  # Удобно скопировать и вставить в терминал
}

output "vm_name" {
  description = "Name of the VM"

  # Берём имя из созданного instance
  value = vkcs_compute_instance.interview.name
}

# -----------------------------------------------------------------------------
# Как использовать outputs:
# -----------------------------------------------------------------------------
# 1. После apply:
#    terraform apply
#    # Выведет все outputs
#
# 2. Получить конкретный output:
#    terraform output vm_ip
#    # Выведет только IP
#
# 3. В формате JSON (для скриптов):
#    terraform output -json
#
# 4. Без кавычек (для shell):
#    terraform output -raw vm_ip
# -----------------------------------------------------------------------------
