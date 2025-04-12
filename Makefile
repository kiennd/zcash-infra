# Makefile for Zcash Infrastructure

# Check if .env file exists and load it
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values if not defined in .env
DATA_DIR ?= /media/data-disk

.PHONY: help
help:
	@echo "Zcash Infrastructure Management"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  setup                  Create all required directories and set permissions"
	@echo "  start-all              Start all services (Zcash, Caddy, and monitoring)"
	@echo "  start-zcash            Start Zcash services only (zcashd and lightwalletd)"
	@echo "  start-zebra            Start Zebra services only (zebra and zaino)"
	@echo "  start-caddy            Start Caddy web server only"
	@echo "  start-monitoring       Start monitoring stack only (Prometheus, Node Exporter, Grafana)"
	@echo "  stop-all               Stop all services"
	@echo "  stop-zcash             Stop Zcash services only"
	@echo "  stop-zebra             Stop Zebra services only"
	@echo "  stop-caddy             Stop Caddy web server only"
	@echo "  stop-monitoring        Stop monitoring stack only"
	@echo "  logs                   Show logs for all services"
	@echo "  status                 Check status of all services"
	@echo "  check-zcash-exporter   Verify the Zcash metrics exporter is working"
	@echo "  restart-zcash-exporter Restart the Zcash metrics exporter container"
	@echo "  build-zaino            Build the Zaino Docker image from source (latest version)"
	@echo "  build-zaino-commit     Build Zaino from a specific commit (usage: make build-zaino-commit COMMIT=<hash>)"
	@echo "  update-zaino-commit    Update docker-compose to use a specific Zaino commit (usage: make update-zaino-commit COMMIT=<hash>)"
	@echo "  clean-zaino            Remove Zaino Docker image and build directory"
	@echo "  clean                  Remove all containers and volumes (WARNING: destructive!)"
	@echo "  clean-networks         Remove all Docker networks (WARNING: destructive!)"
	@echo "  clean-monitoring       Reset Prometheus and Grafana data (WARNING: destructive!)"
	@echo "  help                   Show this help message"

.PHONY: setup
setup:
	@echo "Setting up directories and permissions for Zcash infrastructure..."
	@echo "Using DATA_DIR: $(DATA_DIR)"

	@echo "Creating Zcash service directories..."
	sudo mkdir -p $(DATA_DIR)/zcashd_data
	sudo mkdir -p $(DATA_DIR)/lightwalletd_db_volume
	sudo chown 2002 $(DATA_DIR)/lightwalletd_db_volume

	@echo "Setting up zcash.conf file (updating if necessary)"
	cp zcash.conf.template zcash.conf; \
	sed -i "s/LIGHTWALLETD_RPC_USER/$(LIGHTWALLETD_RPC_USER)/g" zcash.conf; \
	sed -i "s/LIGHTWALLETD_RPC_USER/$(LIGHTWALLETD_RPC_USER)/g" zcash.conf; \
	sed -i "s/LIGHTWALLETD_RPC_PASSWORD/$(LIGHTWALLETD_RPC_PASSWORD)/g" zcash.conf; \
	echo "Created new zcash.conf file with proper credentials. Copying in $(DATA_DIR)/zcashd/zcash.conf"; \
	sudo cp -f zcash.conf $(DATA_DIR)/zcashd_data/zcash.conf

	@echo "Creating Caddy directories..."
	sudo mkdir -p $(DATA_DIR)/caddy_data
	sudo mkdir -p $(DATA_DIR)/caddy_config

	@echo "Creating monitoring directories..."
	sudo mkdir -p $(DATA_DIR)/prometheus_data
	sudo mkdir -p $(DATA_DIR)/grafana_data
	sudo chown 65534:65534 $(DATA_DIR)/prometheus_data
	sudo chown -R 472:0 $(DATA_DIR)/grafana_data
	sudo chmod -R 755 $(DATA_DIR)/grafana_data

	@echo "Creating Docker network..."
	-docker network create zcash-network 2>/dev/null || true

	@echo "Setup complete! You can now start services with 'make start-all'"

.PHONY: start-all
start-all:
	@echo "Starting all services (zcash, caddy, monitoring)..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml up -d
	@echo "All services started successfully"

.PHONY: start-zcash
start-zcash:
	@echo "Starting Zcash services (zcashd + lightwalletd)..."
	docker-compose -f docker-compose.zcash.yml up -d
	@echo "Zcash services started successfully"

.PHONY: start-zebra
start-zebra:
	@cp -f zebra.toml.template zebra.toml
	sed -i "s/ZEBRA_P2P_PORT/$(ZEBRA_P2P_PORT)/g" zebra.toml
	sed -i "s/ZEBRA_RPC_PORT/$(ZEBRA_RPC_PORT)/g" zebra.toml
	sed -i "s/ZEBRA_METRICS_PORT/$(ZEBRA_METRICS_PORT)/g" zebra.toml
	@cp -f zindexer.toml.template zindexer.toml
	sed -i "s/ZAINO_GRPC_PORT/$(ZAINO_GRPC_PORT)/g" zindexer.toml
	sed -i "s/ZEBRA_RPC_PORT/$(ZEBRA_RPC_PORT)/g" zindexer.toml
	@echo "Starting Zebra services..."
	docker-compose -f docker-compose.zebra.yml up -d
	@echo "Zebra services started successfully"

.PHONY: start-caddy
start-caddy:
	@echo "Starting Caddy web server..."
	docker-compose -f docker-compose.caddy.yml up -d
	@echo "Caddy web server started successfully"

.PHONY: start-monitoring
start-monitoring:
	@echo "Starting monitoring stack (Prometheus, Zcashd exporter, Node exporter, Grafana)..."
	docker-compose -f docker-compose.monitoring.yml up -d
	@echo "Monitoring stack started successfully"

.PHONY: stop-all
stop-all:
	@echo "Stopping all services..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml down
	@echo "All services stopped successfully"

.PHONY: stop-zcash
stop-zcash:
	@echo "Stopping Zcash services..."
	docker-compose -f docker-compose.zcash.yml down
	@echo "Zcash services stopped successfully"

.PHONY: stop-zebra
stop-zebra:
	@echo "Stopping Zebra services..."
	docker-compose -f docker-compose.zebra.yml down
	@echo "Zebra services stopped successfully"

.PHONY: stop-caddy
stop-caddy:
	@echo "Stopping Caddy web server..."
	docker-compose -f docker-compose.caddy.yml down
	@echo "Caddy web server stopped successfully"

.PHONY: stop-monitoring
stop-monitoring:
	@echo "Stopping monitoring stack..."
	docker-compose -f docker-compose.monitoring.yml down
	@echo "Monitoring stack stopped successfully"

.PHONY: logs
logs:
	@echo "Showing logs for all services (press Ctrl+C to exit)..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml logs -f

.PHONY: status
status:
	@echo "Service status:"
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml ps

.PHONY: clean
clean:
	@echo "WARNING: This will remove all containers and volumes. Data may be lost!"
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Removing all services and volumes..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml down -v
	@echo "Cleanup complete"

.PHONY: clean-networks
clean-networks:
	@echo "WARNING: This will attempt to remove ALL Docker networks. Running containers will be stopped!"
	@echo "Only the default bridge, host, and none networks will remain."
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Listing all Docker networks before cleanup:"
	docker network ls

	@echo "\nStopping ALL Docker containers..."
	-docker stop $$(docker ps -q) 2>/dev/null

	@echo "\nRemoving all custom Docker networks..."
	-docker network prune -f

	@echo "\nForcefully removing any remaining networks except default ones..."
	@for network in $$(docker network ls --format "{{.Name}}" | grep -v "^bridge$$" | grep -v "^host$$" | grep -v "^none$$"); do \
		echo "Removing network: $$network"; \
		docker network rm $$network 2>/dev/null || true; \
	done

	@echo "\nRemaining networks:"
	docker network ls

	@echo "\nNetwork cleanup complete"

.PHONY: clean-monitoring
clean-monitoring:
	@echo "WARNING: This will remove all Prometheus and Grafana data. Monitoring history will be lost!"
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Stopping monitoring services..."
	docker-compose -f docker-compose.monitoring.yml down

	@echo "Removing Prometheus data..."
	sudo rm -rf $(DATA_DIR)/prometheus_data/*

	@echo "Removing Grafana data..."
	sudo rm -rf $(DATA_DIR)/grafana_data/*

	@echo "Recreating monitoring directories with proper permissions..."
	sudo mkdir -p $(DATA_DIR)/prometheus_data
	sudo mkdir -p $(DATA_DIR)/grafana_data
	sudo chown 65534:65534 $(DATA_DIR)/prometheus_data
	sudo chown -R 472:0 $(DATA_DIR)/grafana_data
	sudo chmod -R 755 $(DATA_DIR)/grafana_data

	@echo "Monitoring data has been cleaned."
	@echo "You can restart the monitoring services with 'make start-monitoring'"

.PHONY: check-zcash-exporter
check-zcash-exporter:
	@echo "Checking Zcash exporter metrics endpoint..."
	@echo "This will show if the exporter is working and collecting metrics from the Zcash node."
	@curl -s http://localhost:9101/metrics | grep zcash || { echo "Failed to get metrics - check if the zcash-exporter container is running"; exit 1; }
	@echo "\nZcash exporter is working correctly and collecting metrics."

.PHONY: restart-zcash-exporter
restart-zcash-exporter:
	@echo "Restarting Zcash exporter container..."
	docker-compose -f docker-compose.monitoring.yml restart zcash-exporter
	@echo "Waiting for exporter to initialize (5 seconds)..."
	@sleep 5
	@echo "Checking metrics endpoint:"
	@curl -s http://localhost:9101/metrics | head -n 10
	@echo "\nZcash exporter has been restarted."

.PHONY: build-zaino
build-zaino:
	@echo "Building Zaino Docker image..."
	@if [ ! -d "tmp/zaino" ]; then \
		echo "Cloning Zaino repository..."; \
		mkdir -p tmp && \
		git clone --depth=1 https://github.com/zingolabs/zaino.git tmp/zaino; \
	else \
		echo "Updating Zaino repository..."; \
		cd tmp/zaino && git pull; \
	fi
	@echo "Applying Dockerfile patch to use latest stable Rust version..."
	@cd tmp/zaino && \
	patch -p1 < ../../zaino-dockerfile-rust.patch || echo "Patch may have already been applied"
	@echo "Building Docker image (this may take a while)..."
	@cd tmp/zaino && \
	docker build -t zingolabs/zaino:latest .
	@echo "Zaino Docker image has been built successfully."
	@echo "You can now start Zebra services with 'make start-zebra'"

.PHONY: build-zaino-commit
build-zaino-commit:
	@if [ -z "$(COMMIT)" ]; then \
		echo "ERROR: COMMIT parameter is required. Usage: make build-zaino-commit COMMIT=<commit-hash>"; \
		exit 1; \
	fi
	@echo "Building Zaino Docker image from commit $(COMMIT)..."
	@if [ ! -d "tmp/zaino" ]; then \
		echo "Cloning Zaino repository..."; \
		mkdir -p tmp && \
		git clone https://github.com/zingolabs/zaino.git tmp/zaino; \
	else \
		echo "Repository already exists, fetching updates..."; \
		cd tmp/zaino && git fetch; \
	fi
	@echo "Checking out commit $(COMMIT)..."
	@cd tmp/zaino && git checkout $(COMMIT)
	@echo "Applying Dockerfile patch to use latest stable Rust version..."
	@cd tmp/zaino && \
	patch -p1 < ../../zaino-dockerfile-rust.patch || echo "Patch may have already been applied"
	@echo "Building Docker image (this may take a while)..."
	@cd tmp/zaino && \
	docker build -t zingolabs/zaino:$(COMMIT) .
	@echo "Zaino Docker image has been built successfully from commit $(COMMIT)."
	@echo "To use this specific commit, run: make update-zaino-commit COMMIT=$(COMMIT)"
	@echo "You can now start Zebra services with 'make start-zebra'"

.PHONY: update-zaino-commit
update-zaino-commit:
	@if [ -z "$(COMMIT)" ]; then \
		echo "ERROR: COMMIT parameter is required. Usage: make update-zaino-commit COMMIT=<commit-hash>"; \
		exit 1; \
	fi
	@echo "Updating docker-compose.zebra.yml to use Zaino commit $(COMMIT)..."
	@sed -i 's|image: zingolabs/zaino:.*|image: zingolabs/zaino:$(COMMIT)  # Build with '\''make build-zaino-commit COMMIT=$(COMMIT)'\''|' docker-compose.zebra.yml
	@echo "Docker Compose configuration updated to use Zaino commit $(COMMIT)."
	@echo "Run 'make start-zebra' to apply the changes."

.PHONY: clean-zaino
clean-zaino:
	@echo "Cleaning Zaino Docker images and build directory..."
	@echo "Removing Zaino Docker images..."
	-docker images zingolabs/zaino --format "{{.Repository}}:{{.Tag}}" | xargs -r docker rmi 2>/dev/null || true
	@echo "Removing Zaino build directory..."
	-rm -rf tmp/zaino
	@echo "Zaino cleanup complete."
