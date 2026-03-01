# API Specification (APS)

## Web Navigator

**Version**: 0.1.0
**Last Updated**: 2026-03-01

---

## 1. Overview

Web Navigator uses Tauri's IPC (Inter-Process Communication) system for communication between the frontend (JavaScript) and backend (Rust). Commands are invoked from the frontend using `window.__TAURI__.core.invoke()` and handled by Rust functions annotated with `#[tauri::command]`.

---

## 2. Tauri Commands

### 2.1 `fetch_url`

Fetches a web page from the given URL and returns the response content.

#### Definition

```rust
#[tauri::command]
fn fetch_url(url: String) -> Result<FetchResult, String>
```

#### Input

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | `String` | Yes | The web address to fetch. If no protocol is specified, `https://` is prepended automatically. |

#### Output — Success (`FetchResult`)

| Field | Type | Description |
|-------|------|-------------|
| `status` | `u16` | HTTP status code (e.g., 200, 301, 404) |
| `body` | `String` | Full response body (typically HTML) |
| `content_type` | `String` | MIME type from the `Content-Type` header (defaults to `text/html`) |
| `final_url` | `String` | The final URL after following redirects |

#### Output — Error

| Field | Type | Description |
|-------|------|-------------|
| (error) | `String` | Human-readable error message describing the failure |

#### Behavior

1. If `url` does not start with `http://` or `https://`, prepend `https://`.
2. Create a reqwest blocking client with:
   - User-Agent: Chrome-like browser string
   - Redirect policy: follow up to 10 redirects
   - Timeout: 30 seconds
3. Send an HTTP GET request.
4. On success: return `FetchResult` with status, body, content type, and final URL.
5. On failure: return an error string describing the issue.

#### Frontend Invocation

```javascript
const result = await invoke("fetch_url", { url: "example.com" });
// result.status    → 200
// result.body      → "<!doctype html>..."
// result.content_type → "text/html; charset=UTF-8"
// result.final_url → "https://example.com/"
```

#### Error Examples

| Scenario | Error Message |
|----------|--------------|
| DNS resolution failure | `"Request failed: error sending request for url (https://invalid.example): ..."` |
| Connection timeout | `"Request failed: operation timed out"` |
| SSL error | `"Request failed: error sending request: invalid peer certificate"` |
| Client creation error | `"Failed to create HTTP client: ..."` |
| Body read error | `"Failed to read response body: ..."` |

---

## 3. IPC Interface

### 3.1 Frontend → Backend

The frontend communicates with the backend using Tauri's `invoke` function:

```javascript
// Import
const { invoke } = window.__TAURI__.core;

// Call
const result = await invoke("command_name", { param1: value1 });
```

### 3.2 Backend → Frontend

The backend returns data as serialized JSON via Tauri's IPC response mechanism. The `Result<T, String>` return type maps to:

- **Ok(T)** → Resolved promise with deserialized `T`
- **Err(String)** → Rejected promise with the error string

### 3.3 Data Schemas

```typescript
// TypeScript equivalent of the Rust types

interface FetchResult {
  status: number;       // HTTP status code
  body: string;         // Response body text
  content_type: string; // Content-Type header value
  final_url: string;    // URL after redirect resolution
}

// Error is a plain string
type FetchError = string;
```

---

## 4. Error Handling Strategy

| Layer | Strategy |
|-------|----------|
| Rust HTTP Client | Errors from reqwest are converted to descriptive strings via `.map_err()` |
| Tauri IPC | `Result<T, String>` — Ok maps to resolved promise, Err maps to rejected promise |
| Frontend JS | `try/catch` around `invoke()` calls; errors displayed in the error view |

### Error Flow

```
reqwest error → map_err(format string) → Result::Err(String)
  → Tauri IPC serialization → Promise.reject(errorString)
    → catch block → display in #error-display
```

---

## 5. Security Notes

- All HTTP requests are made from the Rust backend, not directly from the webview. This prevents CORS issues and provides a controlled network layer.
- The reqwest client does not persist cookies between requests.
- Content is sandboxed within an iframe with restricted permissions.
