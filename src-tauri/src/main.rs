#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use chrono::Utc;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::sync::Mutex;
use tauri::{Manager, State};
use uuid::Uuid;

struct AppState {
    conn: Mutex<Connection>,
}

#[derive(Debug, Serialize)]
struct Note {
    id: String,
    title: String,
    content: String,
    created_at: String,
    updated_at: String,
}

#[derive(Debug, Serialize)]
struct NoteSummary {
    id: String,
    title: String,
    updated_at: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NoteInput {
    title: String,
    content: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AiRequest {
    provider: String,
    action: String,
    content: String,
    api_key: Option<String>,
    model: Option<String>,
    ollama_url: Option<String>,
}

#[derive(Debug, Deserialize)]
struct OpenAiResponse {
    output_text: Option<String>,
    output: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize)]
struct OllamaGenerateResponse {
    response: String,
}

fn init_db(conn: &Connection) -> Result<(), String> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )",
        [],
    )
    .map_err(|err| err.to_string())?;

    Ok(())
}

fn row_to_note(row: &rusqlite::Row<'_>) -> rusqlite::Result<Note> {
    Ok(Note {
        id: row.get(0)?,
        title: row.get(1)?,
        content: row.get(2)?,
        created_at: row.get(3)?,
        updated_at: row.get(4)?,
    })
}

#[tauri::command]
fn list_notes(state: State<'_, AppState>) -> Result<Vec<NoteSummary>, String> {
    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    let mut stmt = conn
        .prepare("SELECT id, title, updated_at FROM notes ORDER BY updated_at DESC")
        .map_err(|err| err.to_string())?;

    let notes = stmt
        .query_map([], |row| {
            Ok(NoteSummary {
                id: row.get(0)?,
                title: row.get(1)?,
                updated_at: row.get(2)?,
            })
        })
        .map_err(|err| err.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|err| err.to_string())?;

    Ok(notes)
}

#[tauri::command]
fn get_note(id: String, state: State<'_, AppState>) -> Result<Note, String> {
    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    conn.query_row(
        "SELECT id, title, content, created_at, updated_at FROM notes WHERE id = ?1",
        params![id],
        row_to_note,
    )
    .map_err(|err| err.to_string())
}

#[tauri::command]
fn create_note(input: NoteInput, state: State<'_, AppState>) -> Result<Note, String> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    let title = input.title.trim();
    let title = if title.is_empty() { "Untitled" } else { title };

    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    conn.execute(
        "INSERT INTO notes (id, title, content, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![id, title, input.content, now, now],
    )
    .map_err(|err| err.to_string())?;

    get_note_from_conn(&conn, &id)
}

#[tauri::command]
fn update_note(id: String, input: NoteInput, state: State<'_, AppState>) -> Result<Note, String> {
    let now = Utc::now().to_rfc3339();
    let title = input.title.trim();
    let title = if title.is_empty() { "Untitled" } else { title };

    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    conn.execute(
        "UPDATE notes SET title = ?1, content = ?2, updated_at = ?3 WHERE id = ?4",
        params![title, input.content, now, id],
    )
    .map_err(|err| err.to_string())?;

    get_note_from_conn(&conn, &id)
}

#[tauri::command]
fn rename_note(id: String, title: String, state: State<'_, AppState>) -> Result<Note, String> {
    let now = Utc::now().to_rfc3339();
    let title = title.trim();
    let title = if title.is_empty() { "Untitled" } else { title };

    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    conn.execute(
        "UPDATE notes SET title = ?1, updated_at = ?2 WHERE id = ?3",
        params![title, now, id],
    )
    .map_err(|err| err.to_string())?;

    get_note_from_conn(&conn, &id)
}

#[tauri::command]
fn delete_note(id: String, state: State<'_, AppState>) -> Result<(), String> {
    let conn = state.conn.lock().map_err(|err| err.to_string())?;
    conn.execute("DELETE FROM notes WHERE id = ?1", params![id])
        .map_err(|err| err.to_string())?;
    Ok(())
}

#[tauri::command]
async fn run_ai(request: AiRequest) -> Result<String, String> {
    let instruction = match request.action.as_str() {
        "improve" => "Improve this markdown note for clarity, flow, and precision. Preserve markdown structure where useful.",
        "summarize" => "Summarize this markdown note into concise bullets and keep important details.",
        "restructure" => "Restructure this markdown note with clearer headings, grouping, and order. Preserve meaning.",
        _ => return Err("Unsupported AI action".to_string()),
    };

    match request.provider.as_str() {
        "openai" => call_openai(&request, instruction).await,
        "ollama" => call_ollama(&request, instruction).await,
        _ => Err("Unsupported AI provider".to_string()),
    }
}

fn get_note_from_conn(conn: &Connection, id: &str) -> Result<Note, String> {
    conn.query_row(
        "SELECT id, title, content, created_at, updated_at FROM notes WHERE id = ?1",
        params![id],
        row_to_note,
    )
    .map_err(|err| err.to_string())
}

async fn call_openai(request: &AiRequest, instruction: &str) -> Result<String, String> {
    let api_key = request
        .api_key
        .as_deref()
        .filter(|key| !key.trim().is_empty())
        .ok_or_else(|| "OpenAI API key is required".to_string())?;
    let model = request.model.as_deref().unwrap_or("gpt-5");

    let client = reqwest::Client::new();
    let response = client
        .post("https://api.openai.com/v1/responses")
        .bearer_auth(api_key)
        .json(&serde_json::json!({
            "model": model,
            "instructions": instruction,
            "input": request.content
        }))
        .send()
        .await
        .map_err(|err| err.to_string())?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("OpenAI request failed ({status}): {body}"));
    }

    let payload: OpenAiResponse = response.json().await.map_err(|err| err.to_string())?;
    extract_openai_text(payload).ok_or_else(|| "OpenAI response did not include text".to_string())
}

async fn call_ollama(request: &AiRequest, instruction: &str) -> Result<String, String> {
    let base_url = request
        .ollama_url
        .as_deref()
        .unwrap_or("http://localhost:11434")
        .trim_end_matches('/');
    let model = request.model.as_deref().unwrap_or("llama3.2");
    let prompt = format!("{instruction}\n\n{}", request.content);

    let client = reqwest::Client::new();
    let response = client
        .post(format!("{base_url}/api/generate"))
        .json(&serde_json::json!({
            "model": model,
            "prompt": prompt,
            "stream": false
        }))
        .send()
        .await
        .map_err(|err| err.to_string())?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("Ollama request failed ({status}): {body}"));
    }

    let payload: OllamaGenerateResponse = response.json().await.map_err(|err| err.to_string())?;
    Ok(payload.response)
}

fn extract_openai_text(payload: OpenAiResponse) -> Option<String> {
    if let Some(text) = payload.output_text {
        if !text.trim().is_empty() {
            return Some(text);
        }
    }

    let mut text = String::new();
    for item in payload.output.unwrap_or_default() {
        if let Some(content) = item.get("content").and_then(Value::as_array) {
            for block in content {
                if let Some(value) = block.get("text").and_then(Value::as_str) {
                    text.push_str(value);
                }
            }
        }
    }

    if text.trim().is_empty() {
        None
    } else {
        Some(text)
    }
}

fn setup_app(app: &mut tauri::App) -> Result<(), String> {
    let app_data_dir = app
        .path()
        .app_data_dir()
        .map_err(|err| format!("Failed to resolve app data directory: {err}"))?;
    fs::create_dir_all(&app_data_dir)
        .map_err(|err| format!("Failed to create app data directory: {err}"))?;

    let db_path = app_data_dir.join("notes.sqlite3");
    let conn = Connection::open(db_path)
        .map_err(|err| format!("Failed to open notes database: {err}"))?;
    init_db(&conn)?;
    app.manage(AppState {
        conn: Mutex::new(conn),
    });

    Ok(())
}

pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            setup_app(app).map_err(|err| IoError::new(ErrorKind::Other, err))?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            list_notes,
            get_note,
            create_note,
            update_note,
            rename_note,
            delete_note,
            run_ai
        ])
        .run(tauri::generate_context!())
        .expect("error while running Zehan");
}

fn main() {
    run();
}
