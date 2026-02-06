output "ducklake_postgres_ip" {
  value       = oci_core_instance.ducklake_postgres.public_ip
  description = "DuckLake PostgreSQL server IP"
}
