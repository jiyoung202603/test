# Software Requirements Specification (SRS)

## Web Navigator

**Version**: 0.1.0
**Last Updated**: 2026-03-01

---

## 1. Introduction

### 1.1 Purpose

This document specifies the functional and non-functional requirements for the Web Navigator application.

### 1.2 Scope

Web Navigator is a cross-platform desktop application built with Tauri that fetches and displays web content.

---

## 2. Functional Requirements

### FR-01: URL Input

- The application SHALL provide a text input field for entering web addresses.
- The input field SHALL support UTF-8 characters.
- Pressing Enter in the input field SHALL trigger navigation.
- A "Go" button SHALL also trigger navigation.

### FR-02: URL Normalization

- If the user omits `https://`, the application SHALL prepend it automatically.
- The application SHALL support both `http://` and `https://` protocols.

### FR-03: Web Content Fetching

- The application SHALL fetch web content using the reqwest HTTP client in the Rust backend.
- The fetch SHALL follow up to 10 redirects.
- The fetch SHALL timeout after 30 seconds.
- The application SHALL send a standard browser User-Agent header.

### FR-04: Content Rendering

- Fetched HTML content SHALL be rendered in an embedded iframe.
- The application SHALL inject a `<base>` tag to resolve relative URLs.
- The application SHALL display the final URL after redirects.

### FR-05: Navigation History

- The application SHALL maintain an in-memory navigation history.
- A "Back" button SHALL navigate to the previous page in history.
- A "Forward" button SHALL navigate to the next page in history.
- A "Reload" button SHALL re-fetch the current page.
- Navigation buttons SHALL be disabled when not applicable.

### FR-06: Error Handling

- The application SHALL display user-friendly error messages on fetch failure.
- Errors SHALL include the specific failure reason.

### FR-07: Status Bar

- The application SHALL display loading status during page fetches.
- The application SHALL show the current URL in the status bar.
- The application SHALL show HTTP status codes on success.

### FR-08: Link Navigation

- Clicking links within rendered content SHALL navigate to the link target.
- The address bar SHALL update to reflect the new URL.

---

## 3. Non-Functional Requirements

### NFR-01: Performance

- Page fetch SHALL complete within 30 seconds or report a timeout error.
- The UI SHALL remain responsive during page loading.

### NFR-02: Internationalization

- All UI elements SHALL support UTF-8 encoding.
- The application SHALL render multilingual content including Korean, Chinese, Japanese, and Swedish characters.
- Font fallback SHALL include Noto Sans variants for CJK languages.

### NFR-03: Platform Support

| Platform | Package Formats |
|----------|----------------|
| Arch Linux | `.run` (self-extracting) |
| Debian/Ubuntu | `.deb` |
| Fedora/RHEL | `.rpm` |
| Windows | `.exe` / `.msi` |
| macOS | `.dmg` / `.app` (universal binary) |

### NFR-04: Window Management

- The window SHALL be resizable.
- Minimum window size: 400x300 pixels.
- Default window size: 1024x768 pixels.

### NFR-05: Security

- Content SHALL be rendered in a sandboxed iframe.
- The iframe sandbox SHALL allow: same-origin, scripts, forms.

---

## 4. Constraints

- Backend: Rust with Tauri 2.x
- Frontend: HTML5 + CSS + vanilla JavaScript (no framework)
- HTTP client: reqwest crate
- Build system: Tauri bundler + custom build.sh

---

## 5. Use Cases

### UC-01: Browse a Website

1. User launches the application.
2. User types a web address (e.g., `example.com`) in the address bar.
3. User presses Enter or clicks Go.
4. Application fetches the page and displays it.
5. User sees the website content rendered in the main area.

### UC-02: Navigate History

1. User has visited multiple pages.
2. User clicks Back to return to a previous page.
3. User clicks Forward to go to the next page.

### UC-03: Handle Errors

1. User enters an invalid or unreachable URL.
2. Application displays an error message with the failure reason.
3. User can enter a new URL to try again.

---

## 6. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-01 | Entering `example.com` and pressing Enter displays the Example Domain page |
| AC-02 | Back button returns to the previously viewed page |
| AC-03 | Forward button goes to the next page in history |
| AC-04 | Reload re-fetches and re-renders the current page |
| AC-05 | Window can be resized below 1024x768 down to 400x300 minimum |
| AC-06 | Korean text (한국어) renders correctly in fetched pages |
| AC-07 | Invalid URLs display a clear error message |
| AC-08 | Status bar shows "Loading..." during fetch and status code after |
