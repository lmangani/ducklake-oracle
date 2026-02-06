.PHONY: all apply terraform-apply deploy init check-env duckdb wait-for-ssh destroy

all: check-env terraform-apply deploy

apply: terraform-apply

check-env:
	@echo "Checking required environment variables..."
	@test -n "$$TF_VAR_oci_tenancy_ocid" || (echo "ERROR: TF_VAR_oci_tenancy_ocid is not set" && exit 1)
	@test -n "$$TF_VAR_oci_user_ocid" || (echo "ERROR: TF_VAR_oci_user_ocid is not set" && exit 1)
	@test -n "$$TF_VAR_oci_fingerprint" || (echo "ERROR: TF_VAR_oci_fingerprint is not set" && exit 1)
	@test -n "$$TF_VAR_oci_compartment_id" || (echo "ERROR: TF_VAR_oci_compartment_id is not set" && exit 1)
	@test -n "$$TF_VAR_oci_namespace" || (echo "ERROR: TF_VAR_oci_namespace is not set" && exit 1)
	@test -n "$$S3_ACCESS_KEY" || (echo "ERROR: S3_ACCESS_KEY is not set" && exit 1)
	@test -n "$$S3_SECRET_KEY" || (echo "ERROR: S3_SECRET_KEY is not set" && exit 1)
	@test -n "$$POSTGRES_DB_PASSWORD" || (echo "ERROR: POSTGRES_DB_PASSWORD is not set" && exit 1)
	@echo "All required environment variables are set"

init:
	cd terraform && terraform init

terraform-apply: check-env
	cd terraform && terraform apply -var="s3_bucket_name=$$S3_BUCKET_NAME"
	mkdir -p data
	cd terraform && terraform output -json ducklake_postgres_ip > ../data/ducklake_postgres_ip.json

wait-for-ssh:
	@echo "Waiting for SSH on $$(cat data/ducklake_postgres_ip.json | tr -d '\"')..."
	@until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -i "$${SSH_KEY_PATH}" opc@$$(cat data/ducklake_postgres_ip.json | tr -d '\"') true 2>/dev/null; do echo "  not ready, retrying..."; sleep 5; done
	@echo "SSH is up"

deploy: wait-for-ssh
	cd config && uv sync
	cd config && pyinfra inventory.py deploy.py --key "$${SSH_KEY_PATH}" --user opc --sudo

destroy:
	cd terraform && terraform destroy -var="s3_bucket_name=$$S3_BUCKET_NAME"

duckdb:
	duckdb -init init.sql
