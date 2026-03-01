# Architecture Design Document (ADD)

## Web Navigator

**Version**: 0.1.0
**Last Updated**: 2026-03-01

---

## 1. System Architecture

Web Navigator follows the standard Tauri 2 architecture: a Rust backend process managing the native window and system resources, with an HTML/CSS/JS frontend rendered in a webview.

### 1.1 High-Level Architecture

```mermaid
graph TB
    subgraph "Desktop Application"
        subgraph "Frontend (WebView)"
            UI[HTML/CSS/JS UI]
            AB[Address Bar]
            NAV[Navigation Controls]
            WV[Content Iframe]
        end

        subgraph "Backend (Rust)"
            TC[Tauri Core]
            CMD[Tauri Commands]
            HTTP[reqwest HTTP Client]
        end
    end

    AB -->|URL input| CMD
    CMD -->|fetch_url| HTTP
    HTTP -->|HTTP request| WEB[Internet]
    WEB -->|Response| HTTP
    HTTP -->|HTML content| CMD
    CMD -->|IPC response| UI
    UI -->|srcdoc| WV
```

### 1.2 Component Diagram

```mermaid
graph LR
    subgraph Frontend
        A[index.html] --> B[styles.css]
        A --> C[app.js]
    end

    subgraph "Tauri IPC Bridge"
        D[invoke API]
    end

    subgraph Backend
        E[main.rs] --> F[lib.rs]
        F --> G[fetch_url command]
        G --> H[reqwest client]
    end

    C -->|invoke| D
    D -->|IPC| G
```

## 2. Data Flow

### 2.1 Page Navigation Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Frontend (JS)
    participant IPC as Tauri IPC
    participant Rust as Backend (Rust)
    participant Web as Internet

    User->>UI: Enter URL + press Enter
    UI->>UI: Normalize URL (add https://)
    UI->>UI: Show "Loading..." status
    UI->>IPC: invoke("fetch_url", {url})
    IPC->>Rust: fetch_url(url: String)
    Rust->>Rust: Create reqwest client
    Rust->>Web: HTTP GET request
    Web-->>Rust: HTTP response
    Rust->>Rust: Extract status, body, content_type
    Rust-->>IPC: Ok(FetchResult)
    IPC-->>UI: FetchResult JSON
    UI->>UI: Inject <base> tag
    UI->>UI: Set iframe.srcdoc
    UI->>UI: Update address bar
    UI->>UI: Update history
    UI->>UI: Show status code
```

### 2.2 Error Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Frontend (JS)
    participant Rust as Backend (Rust)

    User->>UI: Enter invalid URL
    UI->>Rust: invoke("fetch_url", {url})
    Rust->>Rust: Request fails
    Rust-->>UI: Err(String)
    UI->>UI: Show error view
    UI->>UI: Display error message
```

## 3. Technology Stack Rationale

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Backend | Rust + Tauri 2 | Native performance, small binary, cross-platform, memory safety |
| Frontend | HTML5/CSS/JS | No build step needed, lightweight, universal browser compatibility |
| HTTP Client | reqwest | Industry-standard Rust HTTP client, async support, redirect handling |
| IPC | Tauri Commands | Type-safe, secure IPC between frontend and backend |
| Build | Tauri Bundler | Native packaging for all platforms (.deb, .rpm, .msi, .dmg) |

## 4. Module Breakdown

### 4.1 Backend Modules

| Module | File | Responsibility |
|--------|------|---------------|
| Entry Point | `main.rs` | Application bootstrap, calls `lib::run()` |
| Core Library | `lib.rs` | Tauri builder setup, command registration |
| fetch_url | `lib.rs` | HTTP fetching via reqwest, URL normalization, response packaging |

### 4.2 Frontend Modules

| Module | File | Responsibility |
|--------|------|---------------|
| Layout | `index.html` | Page structure: toolbar, status bar, content area |
| Styling | `styles.css` | Dark theme, responsive layout, animations |
| Logic | `app.js` | Navigation, IPC calls, history management, DOM updates |

### 4.3 Key Data Structures

```rust
// Response from backend to frontend
struct FetchResult {
    status: u16,        // HTTP status code
    body: String,       // Response body (HTML)
    content_type: String, // MIME type
    final_url: String,  // URL after redirects
}
```

## 5. Security Considerations

- Content is rendered inside an iframe with `sandbox="allow-same-origin allow-scripts allow-forms"`.
- HTTP requests go through the Rust backend, not directly from the webview.
- The reqwest client enforces a 30-second timeout and 10-redirect limit.
- Tauri's CSP is set to `null` to allow rendering fetched content.
