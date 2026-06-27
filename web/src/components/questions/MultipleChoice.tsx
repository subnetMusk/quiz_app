import { useMemo, useState } from "react";
import type { Question } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { evaluateMultiple } from "../../quiz/evaluate";
import { CodeBlock, ConfirmButton, Feedback } from "../shared";
import { Icon } from "../Icon";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/** Scelta multipla (può avere più risposte corrette). */
export function MultipleChoice({ question, onResult }: Props) {
  const options = useMemo(
    () => [...(question.options ?? [])].sort(() => Math.random() - 0.5),
    [question]
  );
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [detail, setDetail] = useState<ReturnType<typeof evaluateMultiple> | null>(
    null
  );
  const submitted = detail !== null;

  function toggle(id: number) {
    if (submitted) return;
    setSelected((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  function confirm() {
    const d = evaluateMultiple(question, selected);
    setDetail(d);
    onResult(d.result, true);
  }

  function optionClass(id: number, isCorrect: boolean): string {
    if (!submitted) return "option";
    if (detail!.wrongPicked.includes(id)) return "option option--wrong";
    if (isCorrect && selected.has(id)) return "option option--correct";
    if (detail!.missedCorrect.includes(id)) return "option option--missed";
    return "option";
  }

  return (
    <div>
      <CodeBlock code={question.code} />
      <p className="hint">Seleziona tutte le risposte corrette.</p>
      <ul className="options">
        {options.map((o) => (
          <li key={o.id}>
            <label className={optionClass(o.id, o.isCorrect)}>
              <input
                type="checkbox"
                checked={selected.has(o.id)}
                disabled={submitted}
                onChange={() => toggle(o.id)}
              />
              <span>{o.text}</span>
              {submitted && o.isCorrect && (
                <span
                  className={
                    "option__mark " +
                    (selected.has(o.id)
                      ? "option__mark--correct"
                      : "option__mark--missed")
                  }
                  aria-label={selected.has(o.id) ? "corretta" : "corretta non scelta"}
                >
                  <Icon name="check" />
                </span>
              )}
            </label>
          </li>
        ))}
      </ul>

      {!submitted ? (
        <ConfirmButton disabled={selected.size === 0} onClick={confirm} />
      ) : (
        <Feedback result={detail!.result} explanation={question.explanation} />
      )}
    </div>
  );
}
