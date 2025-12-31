# =============================================================================
# main.tf - Основные ресурсы инфраструктуры
# =============================================================================
# Создаём:
# 1. Приватную сеть с подсетью
# 2. Роутер для выхода в интернет
# 3. Security Group (файрвол)
# 4. VM с floating IP
# 5. Ansible inventory
# =============================================================================

# =============================================================================
# NETWORK - Приватная сеть
# =============================================================================

# Получаем внешнюю сеть "internet"
data "vkcs_networking_network" "external" {
  name = "internet"
}

# Создаём приватную сеть
resource "vkcs_networking_network" "private" {
  name = "interview-network"
}

# Создаём подсеть в приватной сети
resource "vkcs_networking_subnet" "private" {
  name            = "interview-subnet"
  network_id      = vkcs_networking_network.private.id
  cidr            = "192.168.100.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Создаём роутер с подключением к внешней сети
resource "vkcs_networking_router" "main" {
  name                = "interview-router"
  external_network_id = data.vkcs_networking_network.external.id
}

# Подключаем роутер к приватной подсети
resource "vkcs_networking_router_interface" "private" {
  router_id = vkcs_networking_router.main.id
  subnet_id = vkcs_networking_subnet.private.id
}

# =============================================================================
# SECURITY GROUP (Файрвол)
# =============================================================================

resource "vkcs_networking_secgroup" "interview" {
  name        = "interview-sg"
  description = "Security group for interview VM"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http_alt" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "https" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "icmp" {
  direction         = "ingress"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

# =============================================================================
# COMPUTE (VM)
# =============================================================================

data "vkcs_compute_flavor" "interview" {
  name = "STD2-1-1"
}

data "vkcs_images_image" "ubuntu" {
  visibility = "public"
  default    = true
  properties = {
    mcs_os_distro  = "ubuntu"
    mcs_os_version = "22.04"
  }
}

resource "vkcs_compute_keypair" "interview" {
  name       = "interview-key"
  public_key = file(var.ssh_public_key_path)
}

resource "vkcs_compute_instance" "interview" {
  name              = var.vm_name
  flavor_id         = data.vkcs_compute_flavor.interview.id
  key_pair          = vkcs_compute_keypair.interview.name
  security_group_ids = [vkcs_networking_secgroup.interview.id]
  availability_zone = var.availability_zone

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = vkcs_networking_network.private.id
  }

  depends_on = [vkcs_networking_router_interface.private]
}

# =============================================================================
# FLOATING IP - Публичный IP для доступа из интернета
# =============================================================================

resource "vkcs_networking_floatingip" "interview" {
  pool = "internet"
}

resource "vkcs_compute_floatingip_associate" "interview" {
  floating_ip = vkcs_networking_floatingip.interview.address
  instance_id = vkcs_compute_instance.interview.id
}

# =============================================================================
# ANSIBLE INVENTORY
# =============================================================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    vm_ip   = vkcs_networking_floatingip.interview.address
    vm_name = var.vm_name
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}
