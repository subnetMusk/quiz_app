import { useMemo, useState } from "react";
import type { Question } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { aggregateResults } from "../../quiz/evaluate";
import { CodeBlock, Feedback } from "../shared";
import { QuestionBody } from "./QuestionBody";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/** Caso di studio / analisi: stimoli comuni + sotto-domande (riusa i renderer atomici). */
export function CaseStudyView({ question, onResult }: Props) {
  const subs = useMemo(() => question.subquestions ?? [], [question]);
  const [, setResults] = useState<Record<string, AnswerResult>>({});
  const [aggregate, setAggregate] = useState<AnswerResult | null>(null);

  function handleSub(id: string, result: AnswerResult) {
    setResults((prev) => {
      const next = { ...prev, [id]: result };
      if (Object.keys(next).length === subs.length && aggregate === null) {
        const agg = aggregateResults(subs.map((s) => next[s.id]));
        setAggregate(agg);
        onResult(agg, true);
      }
      return next;
    });
  }

  return (
    <div>
      {question.stimuli?.map((s) => (
        <div className="stimulus" key={s.id}>
          {s.title && <strong>{s.title}</strong>}
          {s.text && <p style={{ whiteSpace: "pre-wrap" }}>{s.text}</p>}
          <CodeBlock code={s.code} />
          {s.media && (
            <p className="muted">[media non disponibile nella versione web]</p>
          )}
        </div>
      ))}

      {subs.map((sq, i) => (
        <div className="subquestion" key={sq.id}>
          <p className="prompt" style={{ fontSize: "1rem" }}>
            {i + 1}. {sq.prompt}
          </p>
          <QuestionBody question={sq} onResult={(r) => handleSub(sq.id, r)} />
        </div>
      ))}

      {aggregate && (
        <Feedback result={aggregate} explanation={question.explanation} />
      )}
    </div>
  );
}
