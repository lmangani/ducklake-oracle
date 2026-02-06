# Oracle Cloud Infrastructure (OCI) Configuration

variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
  sensitive   = true
}

variable "oci_user_ocid" {
  description = "OCI User OCID"
  type        = string
  sensitive   = true
}

variable "oci_fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
  sensitive   = true
}

variable "oci_private_key_path" {
  description = "Path to OCI API private key"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_region" {
  description = "OCI Region"
  type        = string
  default     = "us-ashburn-1"
}

variable "oci_compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# Configure the Oracle Cloud Infrastructure Provider
provider "oci" {
  tenancy_ocid     = var.oci_tenancy_ocid
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = pathexpand(var.oci_private_key_path)
  region           = var.oci_region
}

# Get the list of availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# Get the latest Oracle Linux 8 ARM64 image
data "oci_core_images" "oracle_linux_arm" {
  compartment_id           = var.oci_compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "ducklake_vcn" {
  compartment_id = var.oci_compartment_id
  display_name   = "ducklake-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "ducklake"
}

# Internet Gateway
resource "oci_core_internet_gateway" "ducklake_ig" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.ducklake_vcn.id
  display_name   = "ducklake-ig"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "ducklake_rt" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.ducklake_vcn.id
  display_name   = "ducklake-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.ducklake_ig.id
  }
}

# Subnet
resource "oci_core_subnet" "ducklake_subnet" {
  compartment_id    = var.oci_compartment_id
  vcn_id            = oci_core_vcn.ducklake_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "ducklake-subnet"
  dns_label         = "ducklakesubnet"
  route_table_id    = oci_core_route_table.ducklake_rt.id
  security_list_ids = [oci_core_security_list.ducklake_sl.id]
}

# Security List (Firewall rules)
resource "oci_core_security_list" "ducklake_sl" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.ducklake_vcn.id
  display_name   = "ducklake-sl"

  # Allow SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow PostgreSQL
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  # Allow all outbound traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Block Volume for additional storage
resource "oci_core_volume" "ducklake_volume" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "ducklake-data-volume"
  size_in_gbs         = 50
}

# Compute Instance (ARM64 - VM.Standard.A1.Flex)
resource "oci_core_instance" "ducklake_postgres" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "ducklake-postgres"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.ducklake_subnet.id
    assign_public_ip = true
    display_name     = "ducklake-postgres-vnic"
  }

  preserve_boot_volume = false
}

# Attach block volume to the instance
resource "oci_core_volume_attachment" "ducklake_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.ducklake_postgres.id
  volume_id       = oci_core_volume.ducklake_volume.id
  display_name    = "ducklake-data-volume-attachment"
}
