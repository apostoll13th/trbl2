output "vm_ip" {
  description = "Public IP address of the VM"
  value       = vkcs_networking_floatingip.interview.address
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ubuntu@${vkcs_networking_floatingip.interview.address}"
}

output "vm_name" {
  description = "Name of the VM"
  value       = vkcs_compute_instance.interview.name
}
