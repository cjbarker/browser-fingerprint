package main

import (
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"log"
	"net"
	"net/http"
	"sort"
	"strings"
	"time"
)

type FingerprintData struct {
	IPAddress     string
	UserAgent     string
	AcceptLang    string
	AcceptEnc     string
	Accept        string
	Headers       map[string]string
	RemoteAddr    string
	XForwardedFor string
	XRealIP       string
	Method        string
	Protocol      string
	TLSVersion    string
	Port          string
}

func extractIPAddress(r *http.Request) string {
	// Check for X-Forwarded-For header (proxy/load balancer)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// Take the first IP in the chain
		ips := strings.Split(xff, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check for X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return strings.TrimSpace(xri)
	}

	// Fall back to RemoteAddr
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return ip
}

func extractHeaders(r *http.Request) map[string]string {
	headers := make(map[string]string)

	// Extract specific headers that are useful for fingerprinting
	fingerprintHeaders := []string{
		"User-Agent",
		"Accept",
		"Accept-Language",
		"Accept-Encoding",
		"Accept-Charset",
		"Connection",
		"Upgrade-Insecure-Requests",
		"Sec-Fetch-Site",
		"Sec-Fetch-Mode",
		"Sec-Fetch-User",
		"Sec-Fetch-Dest",
		"Sec-Ch-Ua",
		"Sec-Ch-Ua-Mobile",
		"Sec-Ch-Ua-Platform",
		"Sec-Ch-Ua-Platform-Version",
		"Sec-Ch-Ua-Arch",
		"Sec-Ch-Ua-Model",
		"Sec-Ch-Ua-Bitness",
		"Sec-Ch-Ua-Full-Version",
		"Sec-Ch-Ua-Full-Version-List",
		"Sec-Ch-Ua-Wow64",
		"Sec-Ch-Viewport-Width",
		"Sec-Ch-Viewport-Height",
		"Sec-Ch-Dpr",
		"Sec-Ch-Device-Memory",
		"Sec-Ch-Prefers-Color-Scheme",
		"Sec-Ch-Prefers-Reduced-Motion",
		"Cache-Control",
		"Pragma",
		"DNT",
		"Referer",
		"Origin",
		"Host",
		"Authorization",
		"X-Requested-With",
		"Content-Type",
		"If-None-Match",
		"If-Modified-Since",
		"X-Forwarded-Proto",
		"X-Forwarded-Port",
		"CF-Ray",
		"CF-IPCountry",
		"CF-Connecting-IP",
		"True-Client-IP",
		"X-Client-IP",
		"X-Cluster-Client-IP",
		"Forwarded",
		"Via",
		"X-Original-Forwarded-For",
		"CloudFront-Viewer-Country",
		"X-Amzn-Trace-Id",
		"Accept-Datetime",
		"TE",
		"Expect",
		"Max-Forwards",
		"Range",
		"Warning",
		"Date",
		"From",
		"Save-Data",
		"Viewport-Width",
		"Width",
		"DPR",
		"Device-Memory",
		"ECT",
		"RTT",
		"Downlink",
	}

	for _, headerName := range fingerprintHeaders {
		if value := r.Header.Get(headerName); value != "" {
			headers[strings.ToLower(headerName)] = value
		}
	}

	return headers
}

func extractAdditionalSignals(r *http.Request) (string, string, string, string) {
	method := r.Method
	protocol := r.Proto

	// Extract port from Host header
	host := r.Host
	port := ""
	if strings.Contains(host, ":") {
		_, port, _ = net.SplitHostPort(host)
	}

	// Extract TLS version if available
	tlsVersion := ""
	if r.TLS != nil {
		switch r.TLS.Version {
		case tls.VersionTLS10:
			tlsVersion = "TLS1.0"
		case tls.VersionTLS11:
			tlsVersion = "TLS1.1"
		case tls.VersionTLS12:
			tlsVersion = "TLS1.2"
		case tls.VersionTLS13:
			tlsVersion = "TLS1.3"
		default:
			tlsVersion = "unknown"
		}
	}

	return method, protocol, tlsVersion, port
}

func generateFingerprint(data FingerprintData) string {
	var parts []string

	// Add IP address
	parts = append(parts, fmt.Sprintf("ip:%s", data.IPAddress))

	// Add request metadata
	parts = append(parts, fmt.Sprintf("method:%s", data.Method))
	parts = append(parts, fmt.Sprintf("protocol:%s", data.Protocol))
	if data.TLSVersion != "" {
		parts = append(parts, fmt.Sprintf("tls:%s", data.TLSVersion))
	}
	if data.Port != "" {
		parts = append(parts, fmt.Sprintf("port:%s", data.Port))
	}

	// Add main headers
	parts = append(parts, fmt.Sprintf("ua:%s", data.UserAgent))
	parts = append(parts, fmt.Sprintf("accept:%s", data.Accept))
	parts = append(parts, fmt.Sprintf("accept-lang:%s", data.AcceptLang))
	parts = append(parts, fmt.Sprintf("accept-enc:%s", data.AcceptEnc))

	// Add other headers in sorted order for consistency
	var headerKeys []string
	for key := range data.Headers {
		if key != "user-agent" && key != "accept" && key != "accept-language" && key != "accept-encoding" {
			headerKeys = append(headerKeys, key)
		}
	}
	sort.Strings(headerKeys)

	for _, key := range headerKeys {
		parts = append(parts, fmt.Sprintf("%s:%s", key, data.Headers[key]))
	}

	// Join all parts and create hash
	fingerprint := strings.Join(parts, "|")

	// Generate SHA-256 hash
	hasher := sha256.New()
	hasher.Write([]byte(fingerprint))
	hash := hex.EncodeToString(hasher.Sum(nil))

	return hash
}

func fingerprintHandler(w http.ResponseWriter, r *http.Request) {
	// Extract additional signals
	method, protocol, tlsVersion, port := extractAdditionalSignals(r)

	// Extract fingerprint data
	data := FingerprintData{
		IPAddress:     extractIPAddress(r),
		UserAgent:     r.Header.Get("User-Agent"),
		AcceptLang:    r.Header.Get("Accept-Language"),
		AcceptEnc:     r.Header.Get("Accept-Encoding"),
		Accept:        r.Header.Get("Accept"),
		Headers:       extractHeaders(r),
		RemoteAddr:    r.RemoteAddr,
		XForwardedFor: r.Header.Get("X-Forwarded-For"),
		XRealIP:       r.Header.Get("X-Real-IP"),
		Method:        method,
		Protocol:      protocol,
		TLSVersion:    tlsVersion,
		Port:          port,
	}

	// Generate fingerprint
	fingerprint := generateFingerprint(data)

	// Output to stdout (as requested)
	fmt.Printf("[%s] Fingerprint: %s | IP: %s | UA: %s\n",
		time.Now().Format(time.RFC3339),
		fingerprint,
		data.IPAddress,
		data.UserAgent)

	// Also return to client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"fingerprint": "%s", "timestamp": "%s"}`, fingerprint, time.Now().Format(time.RFC3339))
}

func main() {
	http.HandleFunc("/fingerprint", fingerprintHandler)

	port := ":8080"
	fmt.Printf("Browser fingerprinting server starting on port %s\n", port)
	fmt.Println("Send requests to http://localhost:8080/fingerprint")

	log.Fatal(http.ListenAndServe(port, nil))
}
