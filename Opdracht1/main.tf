terraform {
  required_providers {
    esxi = {
      source = "josenk/esxi"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "esxi" {
  esxi_hostname = var.esxi_hostname
  esxi_hostport = var.esxi_hostport
  esxi_hostssl  = var.esxi_hostssl
  esxi_username = var.esxi_username
  esxi_password = var.esxi_password
}

locals {
  webservers = ["webserver-1"]
  databases  = ["databaseserver"]
  all_vms    = concat(local.webservers, local.databases)
}

resource "esxi_guest" "vms" {
  for_each = toset(local.all_vms)

  guest_name     = each.value
  disk_store     = var.datastore
  guestos        = "ubuntu-64"
  memsize        = var.memsize
  numvcpus       = var.numvcpus

  network_interfaces {
    virtual_network = var.network
  }

  boot_disk_type  = var.boot_disk_type
  ovf_source      = var.ovf_source

  guestinfo = {
    "userdata" = filebase64("${path.module}/cloud_init.yaml")
    "userdata.encoding" = "base64"
  }
}

resource "local_file" "ansible_inventory" {
  depends_on = [esxi_guest.vms]

  filename = "${path.module}/inventory.ini"

  content = <<EOT
[webservers]
${join("\n", [
  for name, vm in esxi_guest.vms :
  vm.guest_name == "webserver-1" ? "${vm.guest_name} ansible_host=${vm.ip_address} ansible_user=iac ansible_ssh_private_key_file=~/.ssh/skylab" : ""
])}

[databases]
${join("\n", [
  for name, vm in esxi_guest.vms :
  vm.guest_name == "databaseserver" ? "${vm.guest_name} ansible_host=${vm.ip_address} ansible_user=iac ansible_ssh_private_key_file=~/.ssh/skylab" : ""
])}
EOT
} 
