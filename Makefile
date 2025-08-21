# Browser Fingerprinting Server Makefile

# Variables
BINARY_NAME=fingerprint-server
COVERAGE_BINARY=$(BINARY_NAME)-coverage
COVERAGE_DIR=./coverage-data
COVERAGE_OUT=coverage.out
COVERAGE_HTML=coverage.html
MAIN_FILE=main.go
PORT=8080

# Default target
.PHONY: all
all: clean build

# Build the application
.PHONY: build
build:
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) $(MAIN_FILE)
	@echo "Build complete: $(BINARY_NAME)"

# Build with coverage instrumentation
.PHONY: build-coverage
build-coverage:
	@echo "Building $(COVERAGE_BINARY) with coverage instrumentation..."
	go build -cover -o $(COVERAGE_BINARY) $(MAIN_FILE)
	@echo "Coverage build complete: $(COVERAGE_BINARY)"

# Run the application
.PHONY: run
run: build
	@echo "Starting $(BINARY_NAME) on port $(PORT)..."
	./$(BINARY_NAME)

# Run from source (development)
.PHONY: run-dev
run-dev:
	@echo "Running from source..."
	go run $(MAIN_FILE)

# Run basic functional tests
.PHONY: test
test:
	@echo "Running basic tests..."
	@./scripts/test.sh

# Run tests with coverage profiling
.PHONY: test-coverage
test-coverage: build-coverage
	@echo "Running integration tests with coverage profiling..."
	@./scripts/coverage-test.sh
	@echo "Coverage report generated: $(COVERAGE_HTML)"

# Generate coverage reports (requires existing coverage data)
.PHONY: coverage-report
coverage-report:
	@echo "Generating coverage reports..."
	@if [ -d "$(COVERAGE_DIR)" ]; then \
		go tool covdata textfmt -i=$(COVERAGE_DIR) -o=$(COVERAGE_OUT); \
		go tool cover -func=$(COVERAGE_OUT); \
		go tool cover -html=$(COVERAGE_OUT) -o=$(COVERAGE_HTML); \
		echo "Coverage report saved to $(COVERAGE_HTML)"; \
	else \
		echo "No coverage data found. Run 'make test-coverage' first."; \
	fi

# View coverage in browser
.PHONY: coverage-view
coverage-view: coverage-report
	@echo "Opening coverage report in browser..."
	@if command -v open >/dev/null 2>&1; then \
		open $(COVERAGE_HTML); \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open $(COVERAGE_HTML); \
	else \
		echo "Please open $(COVERAGE_HTML) in your browser manually"; \
	fi

# Lint the code
.PHONY: lint
lint:
	@echo "Running golangci-lint..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found. Installing..."; \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
		golangci-lint run; \
	fi

# Format code
.PHONY: fmt
fmt:
	@echo "Formatting code..."
	go fmt ./...
	@echo "Code formatted"

# Vet code for suspicious constructs
.PHONY: vet
vet:
	@echo "Running go vet..."
	go vet ./...
	@echo "Vet completed"

# Run all quality checks
.PHONY: check
check: fmt vet lint
	@echo "All quality checks completed"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(BINARY_NAME)
	@rm -f $(COVERAGE_BINARY)
	@rm -f $(COVERAGE_OUT)
	@rm -f $(COVERAGE_HTML)
	@rm -rf $(COVERAGE_DIR)
	@echo "Clean completed"

# Install dependencies
.PHONY: deps
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download
	@echo "Dependencies installed"

# Create test scripts directory and files
.PHONY: setup-scripts
setup-scripts:
	@echo "Creating test scripts..."
	@mkdir -p scripts
	@echo '#!/bin/bash' > scripts/test.sh
	@echo '# Basic integration tests' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo 'set -e' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo 'echo "Testing fingerprint consistency..."' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo '# Start server in background' >> scripts/test.sh
	@echo 'go run main.go &' >> scripts/test.sh
	@echo 'SERVER_PID=$$!' >> scripts/test.sh
	@echo 'sleep 3' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo '# Cleanup function' >> scripts/test.sh
	@echo 'cleanup() {' >> scripts/test.sh
	@echo '    if kill -0 $$SERVER_PID 2>/dev/null; then' >> scripts/test.sh
	@echo '        kill $$SERVER_PID' >> scripts/test.sh
	@echo '        wait $$SERVER_PID 2>/dev/null || true' >> scripts/test.sh
	@echo '    fi' >> scripts/test.sh
	@echo '}' >> scripts/test.sh
	@echo 'trap cleanup EXIT' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo '# Test server is responding' >> scripts/test.sh
	@echo 'if ! curl -s --max-time 5 http://localhost:8080/fingerprint > /dev/null; then' >> scripts/test.sh
	@echo '    echo "❌ Server not responding"' >> scripts/test.sh
	@echo '    exit 1' >> scripts/test.sh
	@echo 'fi' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo '# Test identical requests (idempotency)' >> scripts/test.sh
	@echo 'RESPONSE1=$$(curl -s http://localhost:8080/fingerprint | grep -o '\''"fingerprint":"[^"]*"'\'' | cut -d'\''"'\'' -f4)' >> scripts/test.sh
	@echo 'RESPONSE2=$$(curl -s http://localhost:8080/fingerprint | grep -o '\''"fingerprint":"[^"]*"'\'' | cut -d'\''"'\'' -f4)' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo 'if [ "$$RESPONSE1" = "$$RESPONSE2" ]; then' >> scripts/test.sh
	@echo '    echo "✅ Idempotency test passed"' >> scripts/test.sh
	@echo 'else' >> scripts/test.sh
	@echo '    echo "❌ Idempotency test failed"' >> scripts/test.sh
	@echo '    exit 1' >> scripts/test.sh
	@echo 'fi' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo '# Test different headers produce different fingerprints' >> scripts/test.sh
	@echo 'RESPONSE3=$$(curl -s -H "User-Agent: DifferentAgent/1.0" http://localhost:8080/fingerprint | grep -o '\''"fingerprint":"[^"]*"'\'' | cut -d'\''"'\'' -f4)' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo 'if [ "$$RESPONSE1" != "$$RESPONSE3" ]; then' >> scripts/test.sh
	@echo '    echo "✅ Uniqueness test passed"' >> scripts/test.sh
	@echo 'else' >> scripts/test.sh
	@echo '    echo "❌ Uniqueness test failed"' >> scripts/test.sh
	@echo '    exit 1' >> scripts/test.sh
	@echo 'fi' >> scripts/test.sh
	@echo '' >> scripts/test.sh
	@echo 'echo "All tests passed!"' >> scripts/test.sh
	@chmod +x scripts/test.sh
	@echo '#!/bin/bash' > scripts/coverage-test.sh
	@echo '# Integration tests with coverage profiling' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo 'set -e' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo 'echo "Running integration tests with coverage..."' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Setup' >> scripts/coverage-test.sh
	@echo 'export GOCOVERDIR=./coverage-data' >> scripts/coverage-test.sh
	@echo 'mkdir -p $$GOCOVERDIR' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Cleanup function' >> scripts/coverage-test.sh
	@echo 'cleanup() {' >> scripts/coverage-test.sh
	@echo '    if [ -n "$$SERVER_PID" ] && kill -0 $$SERVER_PID 2>/dev/null; then' >> scripts/coverage-test.sh
	@echo '        kill $$SERVER_PID' >> scripts/coverage-test.sh
	@echo '        wait $$SERVER_PID 2>/dev/null || true' >> scripts/coverage-test.sh
	@echo '    fi' >> scripts/coverage-test.sh
	@echo '}' >> scripts/coverage-test.sh
	@echo 'trap cleanup EXIT' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Start instrumented server' >> scripts/coverage-test.sh
	@echo './fingerprint-server-coverage &' >> scripts/coverage-test.sh
	@echo 'SERVER_PID=$$!' >> scripts/coverage-test.sh
	@echo 'sleep 3' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Test server is responding' >> scripts/coverage-test.sh
	@echo 'if ! curl -s --max-time 5 http://localhost:8080/fingerprint > /dev/null; then' >> scripts/coverage-test.sh
	@echo '    echo "❌ Coverage server not responding"' >> scripts/coverage-test.sh
	@echo '    exit 1' >> scripts/coverage-test.sh
	@echo 'fi' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo 'echo "Running comprehensive integration tests..."' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Basic request' >> scripts/coverage-test.sh
	@echo 'curl -s http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Different User-Agents' >> scripts/coverage-test.sh
	@echo 'curl -s -H "User-Agent: Mozilla/5.0 (Windows NT 10.0)" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "User-Agent: Mozilla/5.0 (Macintosh)" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Different Accept headers' >> scripts/coverage-test.sh
	@echo 'curl -s -H "Accept: text/html" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "Accept-Language: fr-FR" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "Accept-Encoding: gzip" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Proxy headers' >> scripts/coverage-test.sh
	@echo 'curl -s -H "X-Forwarded-For: 192.168.1.100" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "X-Real-IP: 10.0.0.50" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Security headers' >> scripts/coverage-test.sh
	@echo 'curl -s -H "Sec-Ch-Ua: Chrome" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "Sec-Ch-Ua-Mobile: ?0" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo 'curl -s -H "DNT: 1" http://localhost:8080/fingerprint > /dev/null' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo '# Stop server and generate reports' >> scripts/coverage-test.sh
	@echo 'kill $$SERVER_PID' >> scripts/coverage-test.sh
	@echo 'wait $$SERVER_PID 2>/dev/null || true' >> scripts/coverage-test.sh
	@echo 'SERVER_PID=""' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo 'echo "Generating coverage reports..."' >> scripts/coverage-test.sh
	@echo 'go tool covdata textfmt -i=./coverage-data -o=coverage.out' >> scripts/coverage-test.sh
	@echo 'echo "Coverage summary:"' >> scripts/coverage-test.sh
	@echo 'go tool cover -func=coverage.out | tail -1' >> scripts/coverage-test.sh
	@echo 'go tool cover -html=coverage.out -o=coverage.html' >> scripts/coverage-test.sh
	@echo '' >> scripts/coverage-test.sh
	@echo 'echo "✅ Coverage testing completed successfully!"' >> scripts/coverage-test.sh
	@echo 'echo "📊 Coverage report saved to coverage.html"' >> scripts/coverage-test.sh
	@chmod +x scripts/coverage-test.sh
	@echo "Test scripts created in ./scripts/"

# Full CI pipeline
.PHONY: ci
ci: clean deps check build test
	@echo "🎉 CI pipeline completed successfully!"

# Development workflow
.PHONY: dev
dev: clean deps fmt build test
	@echo "🚀 Development build completed!"

# Help target
.PHONY: help
help:
	@echo "Browser Fingerprinting Server - Available Make Targets:"
	@echo ""
	@echo "Building:"
	@echo "  build              - Build the application binary"
	@echo "  build-coverage     - Build with coverage instrumentation"
	@echo "  clean              - Remove build artifacts and coverage data"
	@echo ""
	@echo "Running:"
	@echo "  run                - Build and run the application"
	@echo "  run-dev            - Run directly from source (development)"
	@echo ""
	@echo "Testing:"
	@echo "  test               - Run basic integration tests"
	@echo "  test-coverage      - Run tests with coverage profiling"
	@echo "  coverage-report    - Generate coverage reports from existing data"
	@echo "  coverage-view      - Generate and open coverage report in browser"
	@echo ""
	@echo "Code Quality:"
	@echo "  lint               - Run golangci-lint"
	@echo "  fmt                - Format code with go fmt"
	@echo "  vet                - Run go vet"
	@echo "  check              - Run all quality checks (fmt, vet, lint)"
	@echo ""
	@echo "Setup & Maintenance:"
	@echo "  deps               - Install and tidy dependencies"
	@echo "  setup-scripts      - Create test script files"
	@echo ""
	@echo "Workflows:"
	@echo "  ci                 - Full CI pipeline (clean, deps, check, build, test)"
	@echo "  dev                - Development workflow (clean, deps, fmt, build, test)"
	@echo "  all                - Default target (clean, build)"
	@echo ""
	@echo "Help:"
	@echo "  help               - Show this help message"
