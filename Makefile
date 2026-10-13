.PHONY: all build clean test run-api run-worker run-audit docker-up docker-down

all: build

build:
	@echo "Building binaries..."
	@go build -o bin/api.exe ./cmd/api
	@go build -o bin/worker.exe ./cmd/worker
	@go build -o bin/audit.exe ./cmd/audit

clean:
	@echo "Cleaning up..."
	@if exist bin rmdir /s /q bin

test:
	@echo "Running tests..."
	@go test -v -race ./...

run-api:
	@go run ./cmd/api

run-worker:
	@go run ./cmd/worker

run-audit:
	@go run ./cmd/audit

docker-up:
	@docker compose -f deployments/docker-compose.yml up -d

docker-down:
	@docker compose -f deployments/docker-compose.yml down

