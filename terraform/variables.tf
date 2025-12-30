# =============================================================================
# variables.tf - Входные переменные
# =============================================================================
# Переменные позволяют параметризировать конфигурацию.
# Значения задаются через:
# - terraform.tfvars файл
# - Переменные окружения TF_VAR_<name>
# - Флаг -var при запуске terraform
# - Интерактивный ввод (если не заданы)
# =============================================================================

# -----------------------------------------------------------------------------
# ОБЯЗАТЕЛЬНЫЕ ПЕРЕМЕННЫЕ (без default - должны быть заданы)
# -----------------------------------------------------------------------------

variable "vkcs_username" {
  # description - описание переменной (для документации и terraform plan)
  description = "VK Cloud username (email)"

  # type - тип данных переменной
  # string = строка, number = число, bool = true/false
  # list(...) = список, map(...) = словарь, object({...}) = объект
  type = string

  # sensitive = true означает:
  # 1. Значение не показывается в terraform plan/apply
  # 2. Значение не логируется
  # 3. Защита от случайного раскрытия секретов
  sensitive = true
}

variable "vkcs_password" {
  description = "VK Cloud password"
  type        = string
  sensitive   = true # Пароль - секрет, скрываем из вывода
}

variable "vkcs_project_id" {
  description = "VK Cloud Project ID"
  type        = string
  # Не sensitive, т.к. project_id не является секретом
  # Его можно видеть в URL и он нужен для отладки
}

# -----------------------------------------------------------------------------
# ОПЦИОНАЛЬНЫЕ ПЕРЕМЕННЫЕ (есть default - можно не задавать)
# -----------------------------------------------------------------------------

variable "vkcs_region" {
  description = "VK Cloud region"
  type        = string

  # default - значение по умолчанию, если переменная не задана
  # RegionOne - основной регион VK Cloud (дата-центр в Москве)
  default = "RegionOne"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string

  # Availability Zone (AZ) - физически изолированная зона в регионе
  # VK Cloud AZ:
  # - GZ1 (Gorizont-1) - основная зона
  # - MS1 (Moscow-1) - альтернативная зона
  # - ME1 (Moscow-East-1) - восточная зона
  # Разные AZ = разные стойки/залы, защита от локальных сбоев
  default = "ME1"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string

  # Путь к публичному SSH ключу
  # ~ = домашняя директория пользователя
  # Этот ключ будет добавлен в VM для SSH доступа
  # Приватный ключ (id_rsa) остаётся у вас для подключения
  default = "~/.ssh/id_rsa.pub"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string

  # Имя виртуальной машины
  # Будет видно в личном кабинете VK Cloud
  # Также используется как hostname внутри VM
  default = "devops-interview"
}
