variable "vkcs_username" {
  description = "VK Cloud username (email)"
  type        = string
  sensitive   = true
}

variable "vkcs_password" {
  description = "VK Cloud password"
  type        = string
  sensitive   = true
}

variable "vkcs_project_id" {
  description = "VK Cloud Project ID"
  type        = string
}

variable "vkcs_region" {
  description = "VK Cloud region"
  type        = string
  default     = "RegionOne"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "GZ1"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "devops-interview"
}
