import type { AnswerRecord } from "../quiz/session";
import { summarize } from "../quiz/session";
import { Icon } from "./Icon";

interface Props {
  subjectName: string;
  records: AnswerRecord[];
  onRestart: () => void;
  onBackToSubjects: () => void;
}

function verdict(pct: number): { text: string; color: string } {
  if (pct >= 85) return { text: "Ottimo lavoro!", color: "var(--green)" };
  if (pct >= 60) return { text: "Buon risultato", color: "var(--green)" };
  if (pct >= 40) return { text: "Si può migliorare", color: "var(--orange)" };
  return { text: "Da ripassare", color: "var(--red)" };
}

/** Anello di accuratezza in stile iOS (AccuracyRing). */
function Ring({ percent, color }: { percent: number; color: string }) {
  const size = 132;
  const stroke = 12;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - percent / 100);
  return (
    <svg className="ring" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle
        className="ring__track"
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        strokeWidth={stroke}
      />
      <circle
        className="ring__value"
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth={stroke}
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text
        className="ring__label"
        x="50%"
        y="50%"
        dominantBaseline="central"
        textAnchor="middle"
      >
        {percent}%
      </text>
    </svg>
  );
}

/** Riepilogo finale della sessione (in memoria, niente persistenza). */
export function Summary({ subjectName, records, onRestart, onBackToSubjects }: Props) {
  const s = summarize(records);
  const v = verdict(s.scorePercent);

  return (
    <section className="card fade-in" aria-labelledby="summary-title">
      <h2 id="summary-title">Riepilogo</h2>
      <p className="lead">{subjectName}</p>

      {s.scored > 0 ? (
        <div className="summary-hero">
          <Ring percent={s.scorePercent} color={v.color} />
          <div className="summary-verdict" style={{ color: v.color }}>
            <Icon name={s.scorePercent >= 60 ? "trophy" : "sparkles"} /> {v.text}
          </div>
        </div>
      ) : (
        <p className="hint">
          Nessuna domanda valutabile in questa sessione (solo domande formative).
        </p>
      )}

      <div className="summary-stats">
        <div className="stat stat--correct">
          <span className="n">{s.correct}</span>
          <span className="lbl">corrette</span>
        </div>
        <div className="stat stat--incomplete">
          <span className="n">{s.incomplete}</span>
          <span className="lbl">parziali</span>
        </div>
        <div className="stat stat--wrong">
          <span className="n">{s.wrong}</span>
          <span className="lbl">sbagliate</span>
        </div>
        {s.formative > 0 && (
          <div className="stat">
            <span className="n">{s.formative}</span>
            <span className="lbl">formative</span>
          </div>
        )}
      </div>

      <p className="hint">
        {s.scored} domande valutate su {s.total} totali.
      </p>

      <div className="btn-row btn-row--stack">
        <button className="btn btn--primary btn--block" onClick={onRestart}>
          <Icon name="arrow" /> Ripeti la materia
        </button>
        <button className="btn btn--ghost" onClick={onBackToSubjects}>
          Torna alle materie
        </button>
      </div>
    </section>
  );
}
