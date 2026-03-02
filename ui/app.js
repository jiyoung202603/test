const { invoke } = window.__TAURI__.core;

const urlInput = document.getElementById("url-input");
const btnGo = document.getElementById("btn-go");
const btnBack = document.getElementById("btn-back");
const btnForward = document.getElementById("btn-forward");
const btnReload = document.getElementById("btn-reload");
const welcome = document.getElementById("welcome");
const webView = document.getElementById("web-view");
const errorDisplay = document.getElementById("error-display");
const errorMessage = document.getElementById("error-message");
const statusText = document.getElementById("status-text");
const statusUrl = document.getElementById("status-url");
const app = document.getElementById("app");

const history = [];
let historyIndex = -1;

function showView(view) {
  welcome.classList.add("hidden");
  webView.classList.add("hidden");
  errorDisplay.classList.add("hidden");

  if (view === "welcome") {
    welcome.classList.remove("hidden");
  } else if (view === "web") {
    webView.classList.remove("hidden");
  } else if (view === "error") {
    errorDisplay.classList.remove("hidden");
  }
}

function setStatus(text, url) {
  statusText.textContent = text;
  statusUrl.textContent = url || "";
}

function updateNavButtons() {
  btnBack.disabled = historyIndex <= 0;
  btnForward.disabled = historyIndex >= history.length - 1;
  btnReload.disabled = historyIndex < 0;
}

function normalizeUrl(input) {
  let url = input.trim();
  if (!url) return "";
  if (!url.match(/^https?:\/\//i)) {
    url = "https://" + url;
  }
  return url;
}

async function navigate(url) {
  url = normalizeUrl(url);
  if (!url) return;

  urlInput.value = url.replace(/^https?:\/\//, "");
  setStatus("Loading...", url);
  app.classList.add("loading");
  showView("web");

  try {
    const result = await invoke("fetch_url", { url });

    if (history[historyIndex] !== url) {
      history.splice(historyIndex + 1);
      history.push(url);
      historyIndex = history.length - 1;
    }

    const contentType = result.content_type || "text/html";
    let body = result.body;

    if (contentType.includes("text/html")) {
      const baseTag = `<base href="${result.final_url}" target="_self">`;
      if (body.includes("<head>")) {
        body = body.replace("<head>", "<head>" + baseTag);
      } else if (body.includes("<html>")) {
        body = body.replace("<html>", "<html><head>" + baseTag + "</head>");
      } else {
        body = "<head>" + baseTag + "</head>" + body;
      }
    }

    webView.srcdoc = body;
    urlInput.value = result.final_url.replace(/^https?:\/\//, "");
    setStatus(`${result.status} OK`, result.final_url);
  } catch (err) {
    errorMessage.textContent = err.toString();
    showView("error");
    setStatus("Error", url);
  } finally {
    app.classList.remove("loading");
    updateNavButtons();
  }
}

// Event listeners
urlInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") {
    navigate(urlInput.value);
  }
});

btnGo.addEventListener("click", () => {
  navigate(urlInput.value);
});

btnBack.addEventListener("click", () => {
  if (historyIndex > 0) {
    historyIndex--;
    navigate(history[historyIndex]);
  }
});

btnForward.addEventListener("click", () => {
  if (historyIndex < history.length - 1) {
    historyIndex++;
    navigate(history[historyIndex]);
  }
});

btnReload.addEventListener("click", () => {
  if (historyIndex >= 0 && history[historyIndex]) {
    navigate(history[historyIndex]);
  }
});

// Intercept link clicks inside the iframe
webView.addEventListener("load", () => {
  try {
    const iframeDoc = webView.contentDocument || webView.contentWindow.document;
    iframeDoc.addEventListener("click", (e) => {
      const anchor = e.target.closest("a");
      if (anchor && anchor.href) {
        e.preventDefault();
        navigate(anchor.href);
      }
    });
  } catch (_) {
    // cross-origin — ignore
  }
});

// Quick links on welcome page
document.querySelectorAll(".quick-link").forEach((link) => {
  link.addEventListener("click", (e) => {
    e.preventDefault();
    const url = link.getAttribute("data-url");
    urlInput.value = url;
    navigate(url);
  });
});

updateNavButtons();
