import React from "react";
import ReactDOM from "react-dom/client";
import { invoke } from "@tauri-apps/api/core";
import DOMPurify from "dompurify";
import { marked } from "marked";
import {
  FilePlus2,
  Save,
  Trash2,
  WandSparkles,
  ListRestart,
  ClipboardList,
  PencilLine,
} from "lucide-react";
import "./styles.css";

type NoteSummary = {
  id: string;
  title: string;
  updated_at: string;
};

type Note = NoteSummary & {
  content: string;
  created_at: string;
};

type Provider = "openai" | "ollama";
type AiAction = "improve" | "summarize" | "restructure";

const starterMarkdown = `# Untitled

Start writing your note here.
`;

marked.setOptions({
  gfm: true,
  breaks: true,
});

function App() {
  const [notes, setNotes] = React.useState<NoteSummary[]>([]);
  const [activeNote, setActiveNote] = React.useState<Note | null>(null);
  const [title, setTitle] = React.useState("Untitled");
  const [content, setContent] = React.useState(starterMarkdown);
  const [status, setStatus] = React.useState("Ready");
  const [isBusy, setIsBusy] = React.useState(false);
  const [provider, setProvider] = React.useState<Provider>("openai");
  const [model, setModel] = React.useState("gpt-5");
  const [openAiKey, setOpenAiKey] = React.useState("");
  const [ollamaUrl, setOllamaUrl] = React.useState("http://localhost:11434");

  const previewHtml = React.useMemo(() => {
    return { __html: DOMPurify.sanitize(String(marked.parse(content))) };
  }, [content]);

  const refreshNotes = React.useCallback(async () => {
    const loaded = await invoke<NoteSummary[]>("list_notes");
    setNotes(loaded);
  }, []);

  React.useEffect(() => {
    refreshNotes().catch((error) => setStatus(String(error)));
  }, [refreshNotes]);

  async function openNote(id: string) {
    setIsBusy(true);
    try {
      const note = await invoke<Note>("get_note", { id });
      setActiveNote(note);
      setTitle(note.title);
      setContent(note.content);
      setStatus("Opened");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setIsBusy(false);
    }
  }

  function newNote() {
    setActiveNote(null);
    setTitle("Untitled");
    setContent(starterMarkdown);
    setStatus("New note");
  }

  async function saveNote() {
    setIsBusy(true);
    try {
      const command = activeNote ? "update_note" : "create_note";
      const payload = activeNote
        ? { id: activeNote.id, input: { title, content } }
        : { input: { title, content } };
      const saved = await invoke<Note>(command, payload);
      setActiveNote(saved);
      setTitle(saved.title);
      setContent(saved.content);
      await refreshNotes();
      setStatus("Saved");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setIsBusy(false);
    }
  }

  async function renameActiveNote() {
    if (!activeNote) {
      await saveNote();
      return;
    }

    setIsBusy(true);
    try {
      const renamed = await invoke<Note>("rename_note", {
        id: activeNote.id,
        title,
      });
      setActiveNote(renamed);
      setTitle(renamed.title);
      await refreshNotes();
      setStatus("Renamed");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setIsBusy(false);
    }
  }

  async function deleteActiveNote() {
    if (!activeNote) return;
    const confirmed = window.confirm(`Delete "${activeNote.title}"?`);
    if (!confirmed) return;

    setIsBusy(true);
    try {
      await invoke("delete_note", { id: activeNote.id });
      await refreshNotes();
      newNote();
      setStatus("Deleted");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setIsBusy(false);
    }
  }

  async function runAi(action: AiAction) {
    if (!content.trim()) {
      setStatus("Add note content first");
      return;
    }

    setIsBusy(true);
    setStatus(`Running ${action}`);
    try {
      const improved = await invoke<string>("run_ai", {
        request: {
          provider,
          action,
          content,
          apiKey: openAiKey,
          model,
          ollamaUrl,
        },
      });
      setContent(improved);
      setStatus("AI update applied");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setIsBusy(false);
    }
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-row">
          <div>
            <h1>Zehan</h1>
            <p>Local markdown notes</p>
          </div>
          <button className="icon-button" onClick={newNote} title="New note">
            <FilePlus2 size={18} />
          </button>
        </div>

        <div className="note-list" aria-label="Notes">
          {notes.map((note) => (
            <button
              key={note.id}
              className={`note-item ${activeNote?.id === note.id ? "active" : ""}`}
              onClick={() => openNote(note.id)}
            >
              <span>{note.title}</span>
              <time>{formatDate(note.updated_at)}</time>
            </button>
          ))}
          {notes.length === 0 && <div className="empty-list">No saved notes</div>}
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <input
            className="title-input"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            onBlur={renameActiveNote}
            aria-label="Note title"
          />
          <div className="toolbar">
            <button onClick={saveNote} disabled={isBusy} title="Save note">
              <Save size={17} />
              Save
            </button>
            <button onClick={deleteActiveNote} disabled={isBusy || !activeNote} title="Delete note">
              <Trash2 size={17} />
              Delete
            </button>
          </div>
        </header>

        <section className="ai-bar" aria-label="AI tools">
          <div className="segmented">
            <button
              className={provider === "openai" ? "selected" : ""}
              onClick={() => {
                setProvider("openai");
                setModel("gpt-5");
              }}
            >
              OpenAI
            </button>
            <button
              className={provider === "ollama" ? "selected" : ""}
              onClick={() => {
                setProvider("ollama");
                setModel("llama3.2");
              }}
            >
              Ollama
            </button>
          </div>
          <input
            className="model-input"
            value={model}
            onChange={(event) => setModel(event.target.value)}
            placeholder="Model"
            aria-label="AI model"
          />
          {provider === "openai" ? (
            <input
              className="key-input"
              value={openAiKey}
              onChange={(event) => setOpenAiKey(event.target.value)}
              placeholder="OpenAI API key"
              type="password"
              aria-label="OpenAI API key"
            />
          ) : (
            <input
              className="key-input"
              value={ollamaUrl}
              onChange={(event) => setOllamaUrl(event.target.value)}
              placeholder="Ollama URL"
              aria-label="Ollama URL"
            />
          )}
          <div className="ai-actions">
            <button onClick={() => runAi("improve")} disabled={isBusy} title="Improve note">
              <WandSparkles size={17} />
              Improve
            </button>
            <button onClick={() => runAi("summarize")} disabled={isBusy} title="Summarize note">
              <ClipboardList size={17} />
              Summarize
            </button>
            <button onClick={() => runAi("restructure")} disabled={isBusy} title="Restructure note">
              <ListRestart size={17} />
              Restructure
            </button>
          </div>
        </section>

        <section className="editor-grid">
          <div className="pane">
            <div className="pane-label">
              <PencilLine size={16} />
              Editor
            </div>
            <textarea
              value={content}
              onChange={(event) => setContent(event.target.value)}
              spellCheck
              aria-label="Markdown editor"
            />
          </div>
          <div className="pane preview-pane">
            <div className="pane-label">Preview</div>
            <article className="markdown-preview" dangerouslySetInnerHTML={previewHtml} />
          </div>
        </section>

        <footer className="status-row">
          <span>{status}</span>
          <span>{activeNote ? `Saved as ${activeNote.title}` : "Unsaved draft"}</span>
        </footer>
      </section>
    </main>
  );
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
