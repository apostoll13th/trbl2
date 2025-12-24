# =============================================================================
# Network
# =============================================================================

data "vkcs_networking_network" "extnet" {
  name = "ext-net"
}

resource "vkcs_networking_network" "interview" {
  name = "interview-network"
}

resource "vkcs_networking_subnet" "interview" {
  name       = "interview-subnet"
  network_id = vkcs_networking_network.interview.id
  cidr       = "192.168.199.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "vkcs_networking_router" "interview" {
  name                = "interview-router"
  admin_state_up      = true
  external_network_id = data.vkcs_networking_network.extnet.id
}

resource "vkcs_networking_router_interface" "interview" {
  router_id = vkcs_networking_router.interview.id
  subnet_id = vkcs_networking_subnet.interview.id
}

# =============================================================================
# Security Group
# =============================================================================

resource "vkcs_networking_secgroup" "interview" {
  name        = "interview-sg"
  description = "Security group for interview VM"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http_alt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

# =============================================================================
# Compute Instance
# =============================================================================

data "vkcs_compute_flavor" "interview" {
  name = "Basic-1-2-20"
}

data "vkcs_images_image" "ubuntu" {
  visibility = "public"
  default    = true
  properties = {
    mcs_os_distro  = "ubuntu"
    mcs_os_version = "24.04"
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
  security_groups   = [vkcs_networking_secgroup.interview.name]
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
    uuid = vkcs_networking_network.interview.id
  }

  depends_on = [
    vkcs_networking_router_interface.interview
  ]
}

# =============================================================================
# Floating IP
# =============================================================================

resource "vkcs_networking_floatingip" "interview" {
  pool = "ext-net"
}

resource "vkcs_compute_floatingip_associate" "interview" {
  floating_ip = vkcs_networking_floatingip.interview.address
  instance_id = vkcs_compute_instance.interview.id
}

# =============================================================================
# Generate Ansible Inventory
# =============================================================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    vm_ip   = vkcs_networking_floatingip.interview.address
    vm_name = var.vm_name
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"

  depends_on = [
    vkcs_compute_floatingip_associate.interview
  ]
}
