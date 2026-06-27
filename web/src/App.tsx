import { useEffect, useState } from "react";
import type { Materia, SubjectIndex, SubjectIndexEntry } from "./quiz/types";
import type { SessionOptions } from "./quiz/session";
import { loadIndex, loadSubject } from "./quiz/loader";
import { SubjectList } from "./components/SubjectList";
import { StartScreen } from "./components/StartScreen";
import { QuizSession } from "./components/QuizSession";
import { Icon } from "./components/Icon";

type Screen =
  | { name: "list" }
  | { name: "config"; materia: Materia }
  | { name: "quiz"; materia: Materia; options: SessionOptions; key: number };

export function App() {
  const [index, setIndex] = useState<SubjectIndex | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loadingSubject, setLoadingSubject] = useState(false);
  const [screen, setScreen] = useState<Screen>({ name: "list" });

  useEffect(() => {
    loadIndex()
      .then(setIndex)
      .catch((e: unknown) =>
        setError(e instanceof Error ? e.message : "Errore di caricamento")
      );
  }, []);

  async function selectSubject(entry: SubjectIndexEntry) {
    setError(null);
    setLoadingSubject(true);
    try {
      const materia = await loadSubject(entry.file);
      setScreen({ name: "config", materia });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Errore di caricamento materia");
    } finally {
      setLoadingSubject(false);
    }
  }

  function goToList() {
    setScreen({ name: "list" });
  }

  return (
    <div className="app">
      <a className="skip-link" href="#main">
        Vai al contenuto
      </a>
      <header className="app__header">
        <h1>Quiz</h1>
        {screen.name !== "list" && (
          <button
            className="btn btn--ghost"
            onClick={goToList}
            style={{ display: "inline-flex", alignItems: "center", gap: 4 }}
          >
            <Icon name="chevron" size={16} className="flip" /> Materie
          </button>
        )}
      </header>

      <main id="main">
        {error && (
          <div className="notice notice--error" role="alert">
            <p>{error}</p>
          </div>
        )}

        {screen.name === "list" && !error && (
          <>
            {index === null ? (
              <div className="notice" role="status">
                <div className="spinner" />
                Caricamento materie…
              </div>
            ) : (
              <>
                <p className="lead">Scegli una materia per iniziare.</p>
                <SubjectList subjects={index.subjects} onSelect={selectSubject} />
              </>
            )}
            {loadingSubject && (
              <div className="notice" role="status">
                <div className="spinner" />
                Caricamento materia…
              </div>
            )}
          </>
        )}

        {screen.name === "config" && (
          <StartScreen
            materia={screen.materia}
            onBack={goToList}
            onStart={(options) =>
              setScreen({ name: "quiz", materia: screen.materia, options, key: Date.now() })
            }
          />
        )}

        {screen.name === "quiz" && (
          <QuizSession
            materia={screen.materia}
            options={screen.options}
            sessionKey={screen.key}
            onBackToSubjects={goToList}
            onRestart={() =>
              setScreen({
                name: "quiz",
                materia: screen.materia,
                options: screen.options,
                key: Date.now(),
              })
            }
          />
        )}
      </main>

      <footer className="app__footer">
        <small>
          Versione web · progressi non salvati (solo in memoria durante la sessione).
        </small>
      </footer>
    </div>
  );
}
