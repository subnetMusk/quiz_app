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

/** Vero/Falso motivato: step 1 il valore V/F, step 2 le motivazioni (pool o lista statica). */
export function TrueFalse({ question, onResult }: Props) {
  // Le motivazioni provengono dal pool randomizzato oppure dalla lista statica legacy.
  const motivations: PoolEntry[] = useMemo(() => {
    if (question.optionPool) return samplePool(question.optionPool) ?? [];
    return (question.motivationOptions ?? []).map((o) => ({
      id: String(o.id),
      text: o.text,
      isCorrect: o.isCorrect,
      canonicalPointId: String(o.id),
    }));
  }, [question]);

  const [tf, setTf] = useState<boolean | null>(null);
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
    const vfWrong = question.answer !== undefined && tf !== question.answer;
    let r: AnswerResult;
    if (vfWrong) r = "wrong";
    else if (motivations.length)
      r = evaluatePoolSelection(motivations, selected).result;
    else r = "correct";
    setResult(r);
    onResult(r, true);
  }

  const vfWrong = submitted && question.answer !== undefined && tf !== question.answer;

  return (
    <div>
      <CodeBlock code={question.code} />
      <fieldset style={{ border: 0, margin: "0 0 var(--gap)", padding: 0 }}>
        <legend className="hint" style={{ padding: 0, marginBottom: 8 }}>
          L'affermazione è vera o falsa?
        </legend>
        <div className="segmented">
          {[
            { label: "Vero", val: true },
            { label: "Falso", val: false },
          ].map(({ label, val }) => (
            <label
              key={label}
              className={
                "option" +
                (submitted && question.answer === val ? " option--correct" : "") +
                (submitted && tf === val && question.answer !== val
                  ? " option--wrong"
                  : "")
              }
            >
              <input
                type="radio"
                name={`tf-${question.id}`}
                checked={tf === val}
                disabled={submitted}
                onChange={() => setTf(val)}
              />
              <span>{label}</span>
            </label>
          ))}
        </div>
      </fieldset>

      {motivations.length > 0 && (
        <PoolSelect
          entries={motivations}
          selected={selected}
          submitted={submitted}
          onToggle={toggle}
          legend="Seleziona le motivazioni corrette."
        />
      )}

      {!submitted ? (
        <ConfirmButton disabled={tf === null} onClick={confirm} />
      ) : (
        <Feedback
          result={result!}
          explanation={
            vfWrong && question.wrongAnswerExplanation
              ? question.wrongAnswerExplanation
              : question.explanation
          }
        />
      )}
    </div>
  );
}
