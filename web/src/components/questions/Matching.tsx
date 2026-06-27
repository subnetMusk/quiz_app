import { useMemo, useState } from "react";
import type { Question } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { evaluateMatching } from "../../quiz/evaluate";
import { CodeBlock, ConfirmButton, Feedback } from "../shared";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/** Abbinamento/collegamento: a ogni elemento di sinistra si assegna uno di destra. */
export function Matching({ question, onResult }: Props) {
  const left = question.left ?? [];
  const right = question.right ?? [];
  // Ordine di presentazione mescolato per i menu (i valori restano gli indici originali).
  const rightOrder = useMemo(
    () => right.map((_, j) => j).sort(() => Math.random() - 0.5),
    [right]
  );

  const [pairs, setPairs] = useState<Record<number, number>>({});
  const [result, setResult] = useState<AnswerResult | null>(null);
  const submitted = result !== null;

  function choose(leftIdx: number, value: string) {
    if (submitted) return;
    setPairs((prev) => {
      const next = { ...prev };
      if (value === "") delete next[leftIdx];
      else next[leftIdx] = Number(value);
      return next;
    });
  }

  function confirm() {
    const r = evaluateMatching(question, pairs);
    setResult(r);
    onResult(r, true);
  }

  const gold = question.correctMatches ?? {};
  const allChosen = left.every((_, i) => pairs[i] !== undefined);

  function rowClass(i: number): string {
    if (!submitted) return "match-row";
    return gold[String(i)] === pairs[i]
      ? "match-row option--correct"
      : "match-row option--wrong";
  }

  return (
    <div>
      <CodeBlock code={question.code} />
      <p className="hint">Associa ogni elemento alla risposta corretta.</p>
      <div role="group" aria-label="Abbinamenti">
        {left.map((item, i) => (
          <div className={rowClass(i)} key={i}>
            <span className="left">{item}</span>
            <select
              aria-label={`Abbinamento per: ${item}`}
              value={pairs[i] ?? ""}
              disabled={submitted}
              onChange={(e) => choose(i, e.target.value)}
            >
              <option value="">— scegli —</option>
              {rightOrder.map((j) => (
                <option value={j} key={j}>
                  {right[j]}
                </option>
              ))}
            </select>
          </div>
        ))}
      </div>

      {!submitted ? (
        <ConfirmButton disabled={!allChosen} onClick={confirm} />
      ) : (
        <Feedback result={result!} explanation={question.explanation}>
          {result !== "correct" && (
            <div className="rubric">
              <h4>Abbinamenti corretti</h4>
              <ul>
                {left.map((item, i) => (
                  <li key={i}>
                    {item} → {right[gold[String(i)]] ?? "—"}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Feedback>
      )}
    </div>
  );
}
