import { useMemo, useState } from "react";
import type { Materia } from "../quiz/types";
import type { SessionOptions } from "../quiz/session";
import { Icon } from "./Icon";

interface Props {
  materia: Materia;
  onStart: (options: SessionOptions) => void;
  onBack: () => void;
}

const COUNT_CHOICES = [10, 20, 50] as const;

/** Configurazione minima della sessione: categoria e numero di domande. */
export function StartScreen({ materia, onStart, onBack }: Props) {
  const [categoryId, setCategoryId] = useState<string>("");
  const [limit, setLimit] = useState<number | "all">(20);

  const available = useMemo(() => {
    const pool = categoryId
      ? materia.questions.filter((q) => q.category === categoryId)
      : materia.questions;
    return pool.length;
  }, [materia, categoryId]);

  function start() {
    onStart({
      categoryId: categoryId || undefined,
      limit: limit === "all" ? undefined : limit,
    });
  }

  return (
    <section className="card fade-in" aria-labelledby="start-title">
      <h2 id="start-title">{materia.meta.subject_name}</h2>
      <p className="lead">{materia.questions.length} domande totali.</p>

      <div className="field">
        <label htmlFor="cat">Categoria</label>
        <select
          id="cat"
          value={categoryId}
          onChange={(e) => setCategoryId(e.target.value)}
        >
          <option value="">Tutte le categorie</option>
          {materia.taxonomy.map((n) => (
            <option value={n.id} key={n.id}>
              {n.name}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="count">Numero di domande</label>
        <select
          id="count"
          value={String(limit)}
          onChange={(e) =>
            setLimit(e.target.value === "all" ? "all" : Number(e.target.value))
          }
        >
          {COUNT_CHOICES.map((c) => (
            <option value={c} key={c}>
              {c}
            </option>
          ))}
          <option value="all">Tutte ({available})</option>
        </select>
      </div>

      <p className="hint">
        Verranno usate {limit === "all" ? available : Math.min(limit, available)}{" "}
        domande, in ordine casuale.
      </p>

      <div className="btn-row btn-row--stack">
        <button
          className="btn btn--primary btn--block"
          onClick={start}
          disabled={available === 0}
        >
          <Icon name="arrow" /> Inizia il quiz
        </button>
        <button className="btn btn--ghost" onClick={onBack}>
          Indietro
        </button>
      </div>
    </section>
  );
}
