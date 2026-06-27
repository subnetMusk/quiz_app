import type { PoolEntry } from "../../quiz/types";
import { Icon } from "../Icon";

interface Props {
  entries: PoolEntry[];
  selected: Set<string>;
  submitted: boolean;
  onToggle: (id: string) => void;
  legend?: string;
}

/** Multi-select su un campione di entry del pool (usato da V/F e risposte aperte con pool). */
export function PoolSelect({ entries, selected, submitted, onToggle, legend }: Props) {
  function cls(e: PoolEntry): string {
    if (!submitted) return "option";
    if (e.isCorrect && selected.has(e.id)) return "option option--correct";
    if (e.isCorrect && !selected.has(e.id)) return "option option--missed";
    if (!e.isCorrect && selected.has(e.id)) return "option option--wrong";
    return "option";
  }

  return (
    <fieldset style={{ border: 0, margin: 0, padding: 0 }}>
      {legend && (
        <legend className="hint" style={{ padding: 0, marginBottom: 8 }}>
          {legend}
        </legend>
      )}
      <ul className="options">
        {entries.map((e) => (
          <li key={e.id}>
            <label className={cls(e)}>
              <input
                type="checkbox"
                checked={selected.has(e.id)}
                disabled={submitted}
                onChange={() => onToggle(e.id)}
              />
              <span>{e.text}</span>
              {submitted && e.isCorrect && (
                <span
                  className={
                    "option__mark " +
                    (selected.has(e.id)
                      ? "option__mark--correct"
                      : "option__mark--missed")
                  }
                  aria-label={selected.has(e.id) ? "corretta" : "corretta non scelta"}
                >
                  <Icon name="check" />
                </span>
              )}
            </label>
          </li>
        ))}
      </ul>
    </fieldset>
  );
}
