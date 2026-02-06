.PHONY: all deploy check-env duckdb setup-storage

all: check-env deploy

check-env:
	@echo "Checking required environment variables..."
	@test -n "$$INSTANCE_IP" || (echo "ERROR: INSTANCE_IP is not set" && exit 1)
	@test -n "$$SSH_KEY_PATH" || (echo "ERROR: SSH_KEY_PATH is not set" && exit 1)
	@test -n "$$POSTGRES_DB_PASSWORD" || (echo "ERROR: POSTGRES_DB_PASSWORD is not set" && exit 1)
	@echo "All required environment variables are set"

deploy: check-env
	@echo "Deploying to $$INSTANCE_IP..."
	@echo "Waiting for SSH to be available..."
	@until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -i "$$SSH_KEY_PATH" $$SSH_USER@$$INSTANCE_IP true 2>/dev/null; do \
		echo "  SSH not ready, retrying..."; \
		sleep 5; \
	done
	@echo "SSH is up"
	cd config && uv sync
	cd config && pyinfra inventory.py deploy.py --key "$$SSH_KEY_PATH" --user $$SSH_USER --sudo
	@echo ""
	@echo "Deployment complete!"
	@echo "Set POSTGRES_HOST=$$INSTANCE_IP in your .env file and run 'make duckdb' to connect"

setup-storage:
	@echo "Setting up block storage on $$INSTANCE_IP..."
	@ssh -i "$$SSH_KEY_PATH" $$SSH_USER@$$INSTANCE_IP 'bash -s' < scripts/setup_block_storage.sh

duckdb:
	@test -n "$$POSTGRES_HOST" || (echo "ERROR: POSTGRES_HOST is not set. Set it to $$INSTANCE_IP" && exit 1)
	duckdb -init init.sql

clean:
	@echo "This will not destroy any Oracle Cloud resources."
	@echo "To clean up, manually terminate your instance from the Oracle Cloud Console."
