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

3. **Compile the application**:
   ```bash
   go build -o fingerprint-server main.go
   ```

## Running the Server

### Method 1: Direct execution
```bash
go run main.go
```

### Method 2: Compiled binary
```bash
./fingerprint-server
```

The server will start on port 8080 and display:
```
Browser fingerprinting server starting on port :8080
Send requests to http://localhost:8080/fingerprint
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

This project is provided as-is for educational and defensive security purposes.