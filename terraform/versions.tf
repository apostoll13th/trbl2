terraform {
  required_version = ">= 1.0.0"

  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.13.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "vkcs" {
  username   = var.vkcs_username
  password   = var.vkcs_password
  project_id = var.vkcs_project_id
  region     = var.vkcs_region
  auth_url   = "https://infra.mail.ru:35357/v3/"
}
