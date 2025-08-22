# Browser Fingerprinting Server

A Go-based HTTP server that generates unique, deterministic fingerprints for web requests based on client characteristics such as HTTP headers, IP address, and other identifying information.

## Overview

This server analyzes incoming HTTP requests to create universally unique fingerprints by examining:

- **IP Address**: Client IP with proxy support (X-Forwarded-For, X-Real-IP)
- **User-Agent**: Browser and OS information
- **Accept Headers**: Content type preferences, language, encoding
- **Security Headers**: Sec-Ch-Ua, Sec-Fetch-* headers
- **Additional Headers**: Connection, Cache-Control, DNT, and more

The fingerprints are:
- **Deterministic**: Identical requests produce identical fingerprints
- **Unique**: Different request characteristics generate different fingerprints
- **Consistent**: Uses SHA-256 hashing for reliable output

## Features

- ✅ Idempotent fingerprint generation
- ✅ Proxy and load balancer support
- ✅ Comprehensive header analysis
- ✅ Real-time stdout logging
- ✅ JSON API responses
- ✅ No external dependencies

## Requirements

- Go 1.21 or higher

## Installation & Compilation

1. **Clone or download the source code**:
   ```bash
   git clone <repository-url>
   cd browser-fingerprint
   ```

2. **Initialize Go module** (if not already done):
   ```bash
   go mod init browser-fingerprint
   ```

3. **Install dependencies**:
   ```bash
   make deps
   ```

4. **Compile the application**:
   ```bash
   make build
   ```

## Running the Server

### Using Makefile (Recommended)
```bash
# Build and run compiled binary
make run

# Run directly from source (development)
make run-dev
```

### Manual Methods
```bash
# Direct execution from source
go run main.go

# Compiled binary
go build -o fingerprint-server main.go
./fingerprint-server
```

The server will start on port 8080 and display:
```
Browser fingerprinting server starting on port :8080
Send requests to http://localhost:8080/fingerprint
```

## Makefile Targets

This project includes a comprehensive Makefile with the following targets:

### Building & Compilation
- **`make build`** - Build the application binary (`fingerprint-server`)
- **`make build-coverage`** - Build with coverage instrumentation for testing
- **`make clean`** - Remove all build artifacts and coverage data
- **`make all`** - Default target (clean + build)

### Running the Application
- **`make run`** - Build and run the compiled binary
- **`make run-dev`** - Run directly from source code (development mode)
- **`make check-port`** - Check if port 8080 is in use and show process info
- **`make kill-port`** - Kill any process running on port 8080

### Testing
- **`make test`** - Run basic integration tests against live server
- **`make test-coverage`** - Run comprehensive tests with coverage profiling
- **`make coverage-report`** - Generate coverage reports from existing data
- **`make coverage-view`** - Generate and open coverage report in browser

### Code Quality & Linting
- **`make lint`** - Run golangci-lint (auto-installs if not present)
- **`make fmt`** - Format code with `go fmt`
- **`make vet`** - Run `go vet` for suspicious constructs
- **`make check`** - Run all quality checks (fmt + vet + lint)

### Setup & Maintenance
- **`make deps`** - Install and tidy Go dependencies
- **`make setup-scripts`** - Create test script files in `./scripts/`

### Workflows
- **`make ci`** - Full CI pipeline (clean → deps → check → build → test)
- **`make dev`** - Development workflow (clean → deps → fmt → build → test)

### Help
- **`make help`** - Display all available targets with descriptions

### Quick Start Examples

```bash
# Complete development setup
make setup-scripts dev

# Run quality checks and tests
make check test-coverage

# Full CI pipeline
make ci

# View test coverage
make coverage-view

# Port management examples
make check-port              # Check if port 8080 is busy
make kill-port run          # Kill existing process and restart
make kill-port run-dev      # Clean development restart
```

## Testing

### Manual Testing

1. **Start the server**:
   ```bash
   go run main.go
   ```

2. **Send test requests**:
   ```bash
   # Basic request
   curl http://localhost:8080/fingerprint
   
   # Request with custom headers
   curl -H "User-Agent: TestBot/1.0" -H "Accept-Language: es-ES" http://localhost:8080/fingerprint
   
   # Request through proxy simulation
   curl -H "X-Forwarded-For: 192.168.1.100" http://localhost:8080/fingerprint
   ```

3. **Verify idempotency**: 
   - Send identical requests multiple times
   - Confirm same fingerprint is generated
   - Change any header and verify new fingerprint is created

### Expected Output

**Stdout logging**:
```
[2025-08-21T16:12:25-07:00] Fingerprint: eafffe11f1639a299ce3c368bdb50d70c3400273b5c1a2ea1ad0d4ddf1be3c0a | IP: ::1 | UA: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36
```

**JSON API response**:
```json
{
  "fingerprint": "eafffe11f1639a299ce3c368bdb50d70c3400273b5c1a2ea1ad0d4ddf1be3c0a",
  "timestamp": "2025-08-21T16:12:25-07:00"
}
```

### Automated Testing

Create a simple test script:

```bash
#!/bin/bash
# test.sh

echo "Testing fingerprint consistency..."

# Start server in background
go run main.go &
SERVER_PID=$!
sleep 2

# Test identical requests
RESPONSE1=$(curl -s http://localhost:8080/fingerprint | jq -r '.fingerprint')
RESPONSE2=$(curl -s http://localhost:8080/fingerprint | jq -r '.fingerprint')

if [ "$RESPONSE1" = "$RESPONSE2" ]; then
    echo "✅ Idempotency test passed"
else
    echo "❌ Idempotency test failed"
fi

# Test different headers
RESPONSE3=$(curl -s -H "User-Agent: DifferentAgent" http://localhost:8080/fingerprint | jq -r '.fingerprint')

if [ "$RESPONSE1" != "$RESPONSE3" ]; then
    echo "✅ Uniqueness test passed"
else
    echo "❌ Uniqueness test failed"
fi

# Cleanup
kill $SERVER_PID
```

### Coverage Profiling for Integration Tests

Go provides built-in coverage profiling support that can be used with integration tests:

#### 1. Build with Coverage Support

```bash
# Build the server with coverage instrumentation
go build -cover -o fingerprint-server-coverage main.go
```

#### 2. Run Server with Coverage Collection

```bash
# Set coverage data output file
export GOCOVERDIR=./coverage-data
mkdir -p $GOCOVERDIR

# Run the instrumented server
./fingerprint-server-coverage &
SERVER_PID=$!
```

#### 3. Execute Integration Tests

```bash
# Run your integration tests while server is running
curl -s http://localhost:8080/fingerprint > /dev/null
curl -s -H "User-Agent: TestAgent" http://localhost:8080/fingerprint > /dev/null
curl -s -H "Accept-Language: fr-FR" http://localhost:8080/fingerprint > /dev/null

# Stop the server to flush coverage data
kill $SERVER_PID
```

#### 4. Generate Coverage Report

```bash
# Convert binary coverage data to text format
go tool covdata textfmt -i=./coverage-data -o=coverage.out

# View coverage report
go tool cover -func=coverage.out

# Generate HTML coverage report
go tool cover -html=coverage.out -o=coverage.html
```

#### 5. Complete Coverage Test Script

```bash
#!/bin/bash
# coverage-test.sh

echo "Running integration tests with coverage..."

# Setup
export GOCOVERDIR=./coverage-data
mkdir -p $GOCOVERDIR
go build -cover -o fingerprint-server-coverage main.go

# Start instrumented server
./fingerprint-server-coverage &
SERVER_PID=$!
sleep 2

# Integration tests
echo "Running integration tests..."
curl -s http://localhost:8080/fingerprint > /dev/null
curl -s -H "User-Agent: Chrome/100" http://localhost:8080/fingerprint > /dev/null
curl -s -H "Accept-Language: es-ES" http://localhost:8080/fingerprint > /dev/null
curl -s -H "X-Forwarded-For: 192.168.1.100" http://localhost:8080/fingerprint > /dev/null

# Stop server and generate reports
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Generating coverage reports..."
go tool covdata textfmt -i=./coverage-data -o=coverage.out
go tool cover -func=coverage.out
go tool cover -html=coverage.out -o=coverage.html

echo "Coverage report saved to coverage.html"

# Cleanup
rm -rf ./coverage-data
rm fingerprint-server-coverage
```

## API Endpoints

### GET /fingerprint

Generates and returns a fingerprint for the requesting client.

**Response**:
```json
{
  "fingerprint": "sha256-hash-string",
  "timestamp": "2025-08-21T16:12:25-07:00"
}
```

**Status Codes**:
- `200 OK`: Fingerprint generated successfully

## Configuration

The server currently runs on port 8080. To change the port, modify the `port` variable in `main.go`:

```go
port := ":9000"  // Change to desired port
```

## Fingerprinting Algorithm

The fingerprint is generated using the following process:

1. **Data Collection**: Extract IP address, headers, and request metadata
2. **Normalization**: Convert header names to lowercase, sort for consistency
3. **Concatenation**: Join all data points with `|` delimiter
4. **Hashing**: Generate SHA-256 hash of the concatenated string

**Example fingerprint components**:
```
ip:192.168.1.1|ua:Mozilla/5.0...|accept:text/html|accept-lang:en-US|accept-enc:gzip|connection:keep-alive
```

## Security Considerations

- This tool is designed for **defensive security purposes** only
- Use for legitimate fingerprinting needs such as fraud detection or analytics
- Ensure compliance with privacy regulations (GDPR, CCPA, etc.)
- Consider user consent requirements in your jurisdiction

## Troubleshooting

**Port already in use**:
```
bind: address already in use
```
- Change the port in `main.go` or kill the process using port 8080

**Module not found**:
```
cannot find module providing package
```
- Run `go mod init browser-fingerprint` to initialize the module

**Permission denied**:
- Ensure the compiled binary has execute permissions: `chmod +x fingerprint-server`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This project is provided for educational and defensive security purposes.