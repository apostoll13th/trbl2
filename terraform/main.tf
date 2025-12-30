# =============================================================================
# main.tf - Основные ресурсы инфраструктуры
# =============================================================================
# Этот файл создаёт:
# 1. Security Group (файрвол)
# 2. Виртуальную машину с публичным IP
# 3. Ansible inventory файл
#
# УПРОЩЁННЫЙ ВАРИАНТ: используем готовую сеть "internet" из VK Cloud
# вместо создания своей сети + роутера + floating IP
# Так же делает UI при создании VM с галочкой "Назначить внешний IP"
# =============================================================================

# =============================================================================
# SECURITY GROUP (Файрвол)
# =============================================================================
# Security Group = набор правил файрвола
# По умолчанию весь входящий трафик ЗАПРЕЩЁН
# Нужно явно разрешить нужные порты
# =============================================================================

resource "vkcs_networking_secgroup" "interview" {
  # Создаём группу безопасности
  # Имя должно быть уникальным в проекте
  name        = "interview-sg"
  description = "Security group for interview VM"
}

# -----------------------------------------------------------------------------
# Правила Security Group
# Каждое правило разрешает определённый тип трафика
# -----------------------------------------------------------------------------

resource "vkcs_networking_secgroup_rule" "ssh" {
  # Разрешаем SSH (порт 22) для удалённого доступа
  #
  # direction - направление трафика:
  #   ingress = входящий (к VM)
  #   egress = исходящий (от VM, обычно разрешён по умолчанию)
  direction = "ingress"

  # protocol - протокол транспортного уровня (tcp, udp, icmp)
  protocol = "tcp"

  # port_range_min/max - диапазон портов
  # Для одного порта: min = max = номер порта
  port_range_min = 22
  port_range_max = 22

  # remote_ip_prefix - откуда разрешён доступ
  # 0.0.0.0/0 = отовсюду (весь интернет)
  # ВНИМАНИЕ: для продакшена лучше ограничить конкретными IP!
  remote_ip_prefix = "0.0.0.0/0"

  # К какой security group относится это правило
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  # Разрешаем HTTP (порт 80) для веб-сервера
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http_alt" {
  # Разрешаем порт 8080 - альтернативный HTTP
  # Используется для: Docker, Tomcat, dev-серверов и т.д.
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "https" {
  # Разрешаем HTTPS (порт 443) для SSL сертификатов
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "icmp" {
  # Разрешаем ICMP (ping) - полезно для диагностики
  direction         = "ingress"
  protocol          = "icmp"
  # У ICMP нет портов, поэтому port_range не указываем
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

# =============================================================================
# COMPUTE (Виртуальная машина)
# =============================================================================

# -----------------------------------------------------------------------------
# data source - получение информации о существующих ресурсах
# В отличие от resource, data НЕ создаёт ресурс, а только читает его
# -----------------------------------------------------------------------------

data "vkcs_compute_flavor" "interview" {
  # Flavor = размер VM (CPU, RAM)
  # Формат имени в VK Cloud: <тип>-<vCPU>-<RAM_GB>-<Disk_GB>
  #
  # Типы:
  #   Basic    - базовая производительность (самый дешёвый)
  #   Standard - стандартная производительность
  #   Advanced - высокая производительность
  #
  # STD2-1-1 или Basic-1-2-20 - зависит от региона
  # Проверь доступные flavors: openstack flavor list
  name = "STD2-1-1"
}

data "vkcs_images_image" "ubuntu" {
  # Image = образ операционной системы
  #
  # visibility:
  #   public  - публичные образы от VK Cloud
  #   private - свои загруженные образы
  visibility = "public"

  # default = true означает использовать образ по умолчанию
  # VK Cloud помечает актуальные версии ОС как default
  default = true

  # properties - фильтрация по метаданным образа
  properties = {
    mcs_os_distro  = "ubuntu"     # дистрибутив: ubuntu, centos, debian...
    mcs_os_version = "22.04"      # версия: 22.04 LTS (Jammy)
  }
}

# -----------------------------------------------------------------------------
# SSH Keypair - ключ для доступа к VM
# -----------------------------------------------------------------------------
resource "vkcs_compute_keypair" "interview" {
  # Имя ключа в VK Cloud (видно в UI)
  name = "interview-key"

  # Публичный ключ загружается из локального файла
  # file() - встроенная функция Terraform для чтения файлов
  # Приватный ключ (id_rsa) остаётся у вас для подключения
  public_key = file(var.ssh_public_key_path)
}

# -----------------------------------------------------------------------------
# Виртуальная машина
# -----------------------------------------------------------------------------
resource "vkcs_compute_instance" "interview" {
  # Имя VM - видно в UI и используется как hostname
  name = var.vm_name

  # Flavor = размер VM (CPU, RAM)
  flavor_id = data.vkcs_compute_flavor.interview.id

  # SSH ключ для доступа (добавится в ~/.ssh/authorized_keys)
  key_pair = vkcs_compute_keypair.interview.name

  # Security Groups - правила файрвола для этой VM
  security_groups = [vkcs_networking_secgroup.interview.name]

  # Availability Zone - физическое размещение в дата-центре
  # GZ1, MS1, ME1 - разные зоны в Москве
  availability_zone = var.availability_zone

  # ---------------------------------------------------------------------------
  # block_device - загрузочный диск VM
  # ---------------------------------------------------------------------------
  block_device {
    # uuid - ID образа ОС
    uuid = data.vkcs_images_image.ubuntu.id

    # source_type - откуда брать данные для диска:
    #   image  - из образа ОС (создаёт новый диск)
    #   volume - из существующего диска
    #   blank  - пустой диск
    source_type = "image"

    # destination_type - тип создаваемого диска:
    #   volume - постоянный диск (сохраняется после удаления VM)
    #   local  - эфемерный диск (удаляется вместе с VM)
    destination_type = "volume"

    # volume_type - тип хранилища:
    #   ceph-ssd     - SSD на Ceph (быстрый, надёжный)
    #   high-iops    - высокопроизводительный SSD
    #   ceph-hdd     - HDD на Ceph (медленнее, дешевле)
    volume_type = "ceph-ssd"

    # volume_size - размер диска в гигабайтах
    volume_size = 20

    # boot_index - порядок загрузки (0 = первый загрузочный диск)
    boot_index = 0

    # delete_on_termination - удалять диск при удалении VM?
    #   true  - диск удалится вместе с VM (для временных VM)
    #   false - диск останется (можно подключить к другой VM)
    delete_on_termination = true
  }

  # ---------------------------------------------------------------------------
  # network - сетевое подключение
  # ---------------------------------------------------------------------------
  # КЛЮЧЕВОЙ МОМЕНТ: используем готовую сеть "internet"
  # Это та же сеть, что выбирается в UI при создании VM
  # VM автоматически получит публичный IP из этой сети!
  # ---------------------------------------------------------------------------
  network {
    # name = "internet" - стандартная сеть VK Cloud с публичными IP
    # Альтернатива: uuid = "<id сети>" если знаете ID
    name = "internet"
  }
}

# =============================================================================
# ANSIBLE INVENTORY
# =============================================================================
# Генерируем файл hosts.yml для Ansible
# Ansible использует inventory чтобы знать на какие серверы подключаться
# =============================================================================

resource "local_file" "ansible_inventory" {
  # templatefile() - рендерит шаблон с подстановкой переменных
  # ${path.module} - путь к директории с этим .tf файлом
  content = templatefile("${path.module}/inventory.tftpl", {
    # access_ip_v4 - публичный IP адрес VM
    # Автоматически назначается при подключении к сети "internet"
    vm_ip   = vkcs_compute_instance.interview.access_ip_v4
    vm_name = var.vm_name
  })

  # Путь для сохранения inventory файла
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}
