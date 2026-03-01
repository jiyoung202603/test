use serde::Serialize;

#[derive(Serialize)]
pub struct FetchResult {
    pub status: u16,
    pub body: String,
    pub content_type: String,
    pub final_url: String,
}

#[derive(Serialize)]
pub struct FetchError {
    pub message: String,
}

#[tauri::command]
fn fetch_url(url: String) -> Result<FetchResult, String> {
    let url = if !url.starts_with("http://") && !url.starts_with("https://") {
        format!("https://{}", url)
    } else {
        url
    };

    let client = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .redirect(reqwest::redirect::Policy::limited(10))
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    let response = client
        .get(&url)
        .send()
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status().as_u16();
    let final_url = response.url().to_string();
    let content_type = response
        .headers()
        .get("content-type")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("text/html")
        .to_string();

    let body = response
        .text()
        .map_err(|e| format!("Failed to read response body: {}", e))?;

    Ok(FetchResult {
        status,
        body,
        content_type,
        final_url,
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![fetch_url])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
