# =============================================================================
# main.tf - Основные ресурсы инфраструктуры
# =============================================================================
# Этот файл создаёт:
# 1. Сеть и подсеть для VM
# 2. Роутер для выхода в интернет
# 3. Security Group (файрвол)
# 4. Виртуальную машину
# 5. Публичный IP (Floating IP)
# 6. Ansible inventory файл
# =============================================================================

# =============================================================================
# СЕТЬ (Network)
# =============================================================================
# В облаке нужно создать свою сеть, т.к. VM не подключаются напрямую к интернету.
# Архитектура: VM -> Private Network -> Router -> External Network -> Internet
# =============================================================================

# -----------------------------------------------------------------------------
# data source - получение информации о существующем ресурсе
# В отличие от resource, data не создаёт ресурс, а читает его
# -----------------------------------------------------------------------------
data "vkcs_networking_network" "extnet" {
  # Получаем информацию о внешней сети VK Cloud
  # "ext-net" - стандартное имя внешней сети в VK Cloud
  # Эта сеть предоставляет доступ в интернет
  # Мы не можем создать эту сеть - она уже существует в облаке
  name = "ext-net"
}

# -----------------------------------------------------------------------------
# resource - создание нового ресурса
# Формат: resource "<тип>" "<локальное_имя>" { ... }
# <тип> - тип ресурса из провайдера (vkcs_networking_network)
# <локальное_имя> - имя для ссылок внутри Terraform (interview)
# -----------------------------------------------------------------------------
resource "vkcs_networking_network" "interview" {
  # Создаём приватную сеть для наших VM
  # Это L2 сеть (как VLAN), изолированная от других проектов
  name = "interview-network"
}

resource "vkcs_networking_subnet" "interview" {
  # Подсеть - это L3 настройки поверх сети (IP адреса, DHCP)
  name = "interview-subnet"

  # Привязываем подсеть к нашей сети
  # .id - атрибут ресурса, появляется после создания
  network_id = vkcs_networking_network.interview.id

  # CIDR - диапазон IP адресов в формате IP/маска
  # 192.168.199.0/24 = адреса 192.168.199.1 - 192.168.199.254
  # /24 = маска 255.255.255.0 = 254 доступных адреса
  cidr = "192.168.199.0/24"

  # DNS серверы для VM в этой подсети
  # 8.8.8.8, 8.8.4.4 - публичные DNS Google
  # VM получат эти DNS через DHCP
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# -----------------------------------------------------------------------------
# Роутер - соединяет приватную сеть с внешней (интернет)
# -----------------------------------------------------------------------------
resource "vkcs_networking_router" "interview" {
  name = "interview-router"

  # admin_state_up = true означает что роутер включён
  # false = роутер создан но не работает
  admin_state_up = true

  # Подключаем роутер к внешней сети
  # Это даёт роутеру доступ в интернет
  # data.vkcs_networking_network.extnet.id - ID внешней сети
  external_network_id = data.vkcs_networking_network.extnet.id
}

resource "vkcs_networking_router_interface" "interview" {
  # Интерфейс роутера - подключение роутера к подсети
  # Роутер получит IP в этой подсети и будет gateway для VM

  router_id = vkcs_networking_router.interview.id
  subnet_id = vkcs_networking_subnet.interview.id

  # После этого VM в подсети смогут выходить в интернет через роутер
  # Маршрут по умолчанию (0.0.0.0/0) будет указывать на роутер
}

# =============================================================================
# SECURITY GROUP (Файрвол)
# =============================================================================
# Security Group = набор правил файрвола
# По умолчанию весь входящий трафик ЗАПРЕЩЁН
# Нужно явно разрешить нужные порты
# =============================================================================

resource "vkcs_networking_secgroup" "interview" {
  # Создаём группу безопасности
  name        = "interview-sg"
  description = "Security group for interview VM"
}

# -----------------------------------------------------------------------------
# Правила Security Group
# Каждое правило разрешает определённый тип трафика
# -----------------------------------------------------------------------------

resource "vkcs_networking_secgroup_rule" "ssh" {
  # Разрешаем SSH (порт 22) для удалённого доступа

  # direction - направление трафика
  # ingress = входящий (к VM), egress = исходящий (от VM)
  direction = "ingress"

  # ethertype - версия IP протокола
  # IPv4 или IPv6
  ethertype = "IPv4"

  # protocol - протокол транспортного уровня
  # tcp, udp, icmp, или номер протокола
  protocol = "tcp"

  # port_range_min/max - диапазон портов
  # Для одного порта min = max
  port_range_min = 22
  port_range_max = 22

  # remote_ip_prefix - откуда разрешён доступ
  # 0.0.0.0/0 = отовсюду (весь интернет)
  # Для продакшена лучше ограничить конкретными IP
  remote_ip_prefix = "0.0.0.0/0"

  # К какой security group относится правило
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  # Разрешаем HTTP (порт 80) для веб-сервера
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http_alt" {
  # Разрешаем альтернативный HTTP порт 8080
  # Часто используется для приложений (Docker, Tomcat, etc.)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "icmp" {
  # Разрешаем ICMP (ping)
  # Полезно для диагностики сети
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  # Для ICMP не указываем порты (их нет в ICMP)
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

# =============================================================================
# COMPUTE (Виртуальная машина)
# =============================================================================

# -----------------------------------------------------------------------------
# Flavor = размер VM (CPU, RAM, диск)
# Получаем существующий flavor по имени
# -----------------------------------------------------------------------------
data "vkcs_compute_flavor" "interview" {
  # Формат имени: <тип>-<vCPU>-<RAM_GB>-<Disk_GB>
  # Basic-1-2-20 = Basic тип, 1 vCPU, 2 GB RAM, 20 GB диск
  # Типы: Basic, Standard, Advanced (отличаются производительностью)
  name = "Basic-1-2-20"
}

# -----------------------------------------------------------------------------
# Image = образ ОС для установки на VM
# -----------------------------------------------------------------------------
data "vkcs_images_image" "ubuntu" {
  # visibility = "public" - публичные образы от VK Cloud
  # private - свои загруженные образы
  visibility = "public"

  # default = true - использовать образ по умолчанию
  # VK Cloud помечает актуальные версии как default
  default = true

  # properties - фильтрация по метаданным образа
  properties = {
    # mcs_os_distro - дистрибутив ОС
    mcs_os_distro = "ubuntu"
    # mcs_os_version - версия ОС
    # 24.04 = Ubuntu 24.04 LTS (Noble Numbat)
    mcs_os_version = "24.04"
  }
}

# -----------------------------------------------------------------------------
# SSH Keypair = ключ для SSH доступа к VM
# -----------------------------------------------------------------------------
resource "vkcs_compute_keypair" "interview" {
  # Имя ключа в VK Cloud
  name = "interview-key"

  # Публичный ключ загружается из локального файла
  # file() - функция Terraform для чтения файла
  # var.ssh_public_key_path = ~/.ssh/id_rsa.pub
  public_key = file(var.ssh_public_key_path)

  # При создании VM этот ключ добавится в ~/.ssh/authorized_keys
  # После чего можно подключаться: ssh -i ~/.ssh/id_rsa ubuntu@<IP>
}

# -----------------------------------------------------------------------------
# Виртуальная машина
# -----------------------------------------------------------------------------
resource "vkcs_compute_instance" "interview" {
  # Имя VM (видно в личном кабинете и как hostname)
  name = var.vm_name

  # Flavor = размер VM (ссылаемся на data source выше)
  flavor_id = data.vkcs_compute_flavor.interview.id

  # SSH ключ для доступа
  key_pair = vkcs_compute_keypair.interview.name

  # Security Groups = правила файрвола
  # Можно указать несколько групп
  security_groups = [vkcs_networking_secgroup.interview.name]

  # Зона доступности (физическое размещение)
  availability_zone = var.availability_zone

  # ---------------------------------------------------------------------------
  # block_device - диск VM
  # В VK Cloud диски создаются отдельно и подключаются к VM
  # ---------------------------------------------------------------------------
  block_device {
    # uuid - ID образа ОС для установки
    uuid = data.vkcs_images_image.ubuntu.id

    # source_type - тип источника для диска
    # image = создать диск из образа ОС
    # volume = использовать существующий диск
    # blank = пустой диск
    source_type = "image"

    # destination_type - куда записать
    # volume = создать постоянный диск (SSD/HDD)
    # local = эфемерный диск (удалится с VM)
    destination_type = "volume"

    # volume_type - тип хранилища
    # ceph-ssd = SSD на базе Ceph (быстрый, надёжный)
    # ceph-hdd = HDD на базе Ceph (медленнее, дешевле)
    volume_type = "ceph-ssd"

    # volume_size - размер диска в GB
    volume_size = 20

    # boot_index - порядок загрузки (0 = первый, загрузочный)
    boot_index = 0

    # delete_on_termination - удалять диск при удалении VM
    # true = диск удалится вместе с VM
    # false = диск останется (можно подключить к другой VM)
    delete_on_termination = true
  }

  # ---------------------------------------------------------------------------
  # network - сетевое подключение VM
  # ---------------------------------------------------------------------------
  network {
    # uuid - ID сети для подключения
    # VM получит IP в этой сети через DHCP
    uuid = vkcs_networking_network.interview.id
  }

  # ---------------------------------------------------------------------------
  # depends_on - явная зависимость
  # ---------------------------------------------------------------------------
  # Terraform обычно сам понимает зависимости по ссылкам
  # Но иногда нужно указать явно
  # Здесь: VM зависит от подключения роутера к подсети
  # Без роутера VM не сможет выйти в интернет
  depends_on = [
    vkcs_networking_router_interface.interview
  ]
}

# =============================================================================
# FLOATING IP (Публичный IP адрес)
# =============================================================================
# Floating IP = публичный IP, который можно присвоить VM
# В отличие от приватного IP, Floating IP доступен из интернета
# =============================================================================

resource "vkcs_networking_floatingip" "interview" {
  # pool - пул публичных адресов
  # "ext-net" - стандартный пул в VK Cloud
  pool = "ext-net"

  # VK Cloud выделит свободный IP из пула
  # Этот IP будет нашим публичным адресом
}

resource "vkcs_compute_floatingip_associate" "interview" {
  # Привязываем Floating IP к VM

  # floating_ip - публичный IP адрес
  # .address - атрибут с самим IP (например, 89.208.xxx.xxx)
  floating_ip = vkcs_networking_floatingip.interview.address

  # instance_id - ID виртуальной машины
  instance_id = vkcs_compute_instance.interview.id

  # После этого VM доступна из интернета по этому IP
  # NAT: публичный IP -> приватный IP VM
}

# =============================================================================
# ANSIBLE INVENTORY
# =============================================================================
# Генерируем файл inventory для Ansible
# Ansible использует inventory чтобы знать куда подключаться
# =============================================================================

resource "local_file" "ansible_inventory" {
  # content - содержимое файла
  # templatefile() - функция для рендеринга шаблона
  # Аргументы: путь к шаблону, переменные для шаблона
  content = templatefile("${path.module}/inventory.tftpl", {
    # Переменные доступные в шаблоне
    vm_ip   = vkcs_networking_floatingip.interview.address
    vm_name = var.vm_name
  })

  # filename - путь для сохранения файла
  # ${path.module} = директория где лежит этот .tf файл
  filename = "${path.module}/../ansible/inventory/hosts.yml"

  # Файл создаётся только после привязки Floating IP
  # Иначе IP адрес ещё не будет известен
  depends_on = [
    vkcs_compute_floatingip_associate.interview
  ]
}
