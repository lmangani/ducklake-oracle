# Oracle Cloud Object Storage Configuration

variable "s3_bucket_name" {
  description = "Object Storage bucket name (must be globally unique)"
  type        = string
}

variable "oci_namespace" {
  description = "OCI Object Storage namespace"
  type        = string
}

# Create Object Storage bucket
resource "oci_objectstorage_bucket" "ducklake_bucket" {
  compartment_id = var.oci_compartment_id
  namespace      = var.oci_namespace
  name           = var.s3_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"
}

# Create Customer Secret Key for S3 compatibility
# Note: This resource doesn't export the secret key value directly
# You need to create it manually in the OCI Console or via CLI
# and provide it in the environment variables
output "bucket_name" {
  value       = oci_objectstorage_bucket.ducklake_bucket.name
  description = "Object Storage bucket name"
}

output "object_storage_namespace" {
  value       = var.oci_namespace
  description = "Object Storage namespace"
}
