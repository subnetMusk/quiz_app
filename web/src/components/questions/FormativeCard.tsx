import { useState } from "react";
import type { Question } from "../../quiz/types";
import { kindDisplayName } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { CodeBlock } from "../shared";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/**
 * Domande formative o non interattive nel web (risposte aperte senza pool, cloze,
 * riordino, calcolo, ecc.): mostra la domanda, raccoglie una risposta libera facoltativa
 * e rivela la soluzione di riferimento. Non concorrono al punteggio.
 */
export function FormativeCard({ question, onResult }: Props) {
  const [revealed, setRevealed] = useState(false);

  function reveal() {
    setRevealed(true);
    onResult("incomplete", false); // non valutata: esclusa dal punteggio
  }

  const accepted = question.acceptedAnswers;
  const model = question.expectedAnswer ?? question.sampleSolution;

  return (
    <div>
      <CodeBlock code={question.code} />
      {question.givens && question.givens.length > 0 && (
        <ul>
          {question.givens.map((g, i) => (
            <li key={i}>{g}</li>
          ))}
        </ul>
      )}
      <p className="muted">
        Domanda di tipo «{kindDisplayName[question.kind]}»: rispondi mentalmente o per
        iscritto, poi confronta con la soluzione. Non incide sul punteggio.
      </p>
      <label className="field">
        <span className="muted">La tua risposta (facoltativa)</span>
        <textarea
          rows={4}
          disabled={revealed}
          style={{
            font: "inherit",
            padding: 12,
            borderRadius: 10,
            border: "1px solid var(--border)",
            background: "var(--surface)",
            color: "var(--text)",
            resize: "vertical",
          }}
        />
      </label>

      {!revealed ? (
        <div className="btn-row">
          <button className="btn btn--primary" onClick={reveal}>
            Mostra soluzione
          </button>
        </div>
      ) : (
        <div className="feedback">
          {model && (
            <div className="rubric">
              <h4>Risposta modello</h4>
              <p style={{ whiteSpace: "pre-wrap" }}>{model}</p>
            </div>
          )}
          {accepted && accepted.length > 0 && (
            <div className="rubric">
              <h4>Risposte accettate</h4>
              <p>{accepted.join(" · ")}</p>
            </div>
          )}
          {question.items && question.items.length > 0 && (
            <div className="rubric">
              <h4>Ordine corretto</h4>
              <ol>
                {question.items.map((it, i) => (
                  <li key={i}>{it}</li>
                ))}
              </ol>
            </div>
          )}
          {question.keyPoints && question.keyPoints.length > 0 && (
            <div className="rubric">
              <h4>Punti chiave</h4>
              <ul>
                {question.keyPoints.map((k, i) => (
                  <li key={i}>{k}</li>
                ))}
              </ul>
            </div>
          )}
          {question.requiredCriteria && question.requiredCriteria.length > 0 && (
            <div className="rubric">
              <h4>Criteri richiesti</h4>
              <ul>
                {question.requiredCriteria.map((k, i) => (
                  <li key={i}>{k}</li>
                ))}
              </ul>
            </div>
          )}
          {question.commonMistakes && question.commonMistakes.length > 0 && (
            <div className="rubric">
              <h4>Errori comuni</h4>
              <ul>
                {question.commonMistakes.map((k, i) => (
                  <li key={i}>{k}</li>
                ))}
              </ul>
            </div>
          )}
          {question.explanation && (
            <div className="rubric">
              <h4>Spiegazione</h4>
              <p style={{ whiteSpace: "pre-wrap" }}>{question.explanation}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
