import { useMemo, useState } from "react";
import type { PoolEntry, Question } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { evaluatePoolSelection, samplePool } from "../../quiz/pool";
import { CodeBlock, ConfirmButton, Feedback } from "../shared";
import { PoolSelect } from "./PoolSelect";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/**
 * Risposte aperte/guidate dotate di `optionPool`: in iOS sono valutabili tramite una
 * checklist di affermazioni corrette. Qui le rendiamo come multi-select valutato.
 */
export function PoolQuestion({ question, onResult }: Props) {
  const entries: PoolEntry[] = useMemo(
    () => (question.optionPool ? samplePool(question.optionPool) ?? [] : []),
    [question]
  );
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [result, setResult] = useState<AnswerResult | null>(null);
  const submitted = result !== null;

  function toggle(id: string) {
    if (submitted) return;
    setSelected((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  function confirm() {
    const r = evaluatePoolSelection(entries, selected).result;
    setResult(r);
    onResult(r, true);
  }

  return (
    <div>
      <CodeBlock code={question.code} />
      <PoolSelect
        entries={entries}
        selected={selected}
        submitted={submitted}
        onToggle={toggle}
        legend="Seleziona le affermazioni corrette."
      />
      {!submitted ? (
        <ConfirmButton disabled={selected.size === 0} onClick={confirm} />
      ) : (
        <Feedback result={result!} explanation={question.explanation}>
          {(question.expectedAnswer || question.sampleSolution) && (
            <div className="rubric">
              <h4>Risposta modello</h4>
              <p style={{ whiteSpace: "pre-wrap" }}>
                {question.expectedAnswer ?? question.sampleSolution}
              </p>
            </div>
          )}
        </Feedback>
      )}
    </div>
  );
}
