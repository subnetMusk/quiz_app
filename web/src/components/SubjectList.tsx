import type { QuestionKind, SubjectIndexEntry } from "../quiz/types";
import { kindDisplayName } from "../quiz/types";
import { Icon, type IconName } from "./Icon";

interface Props {
  subjects: SubjectIndexEntry[];
  onSelect: (s: SubjectIndexEntry) => void;
}

// Palette ispirata alle "mode card" iOS: ogni materia prende un colore/icona.
const ACCENTS: { color: string; icon: IconName }[] = [
  { color: "var(--indigo)", icon: "book" },
  { color: "var(--green)", icon: "cards" },
  { color: "var(--orange)", icon: "scale" },
  { color: "var(--purple)", icon: "doc" },
  { color: "var(--teal)", icon: "list" },
  { color: "var(--pink)", icon: "sparkles" },
];

/** Elenco delle materie disponibili. */
export function SubjectList({ subjects, onSelect }: Props) {
  if (subjects.length === 0) {
    return (
      <div className="notice" role="status">
        <p className="muted">Nessuna materia trovata.</p>
      </div>
    );
  }

  return (
    <ul className="subject-grid">
      {subjects.map((s, i) => {
        const accent = ACCENTS[i % ACCENTS.length];
        return (
          <li key={s.id}>
            <button
              className="btn card subject-card fade-in"
              onClick={() => onSelect(s)}
            >
              <span className="subject-icon" style={{ background: accent.color }}>
                <Icon name={accent.icon} size={24} />
              </span>
              <h2>{s.name}</h2>
              <span className="subject-count">
                {s.questionCount}
                <Icon name="chevron" size={16} />
              </span>
              <span className="chip-row">
                {Object.entries(s.kinds).map(([k, n]) => (
                  <span className="chip chip--neutral" key={k}>
                    {kindDisplayName[k as QuestionKind] ?? k}: {n}
                  </span>
                ))}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
