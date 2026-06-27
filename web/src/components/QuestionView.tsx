import { useState } from "react";
import type { Question, QuestionKind } from "../quiz/types";
import { kindDisplayName } from "../quiz/types";
import type { AnswerResult } from "../quiz/evaluate";
import type { AnswerRecord } from "../quiz/session";
import { QuestionBody } from "./questions/QuestionBody";
import { CaseStudyView } from "./questions/CaseStudyView";
import { Icon, type IconName } from "./Icon";

const KIND_ICON: Record<QuestionKind, IconName> = {
  multiple: "list",
  matching: "link",
  trueFalseMotivated: "scale",
  clozeWordBank: "doc",
  shortAnswer: "doc",
  ordered: "list",
  calculation: "scale",
  openRubric: "doc",
  constructedResponse: "doc",
  mediaAnalysis: "case",
  caseStudy: "case",
};

interface Props {
  question: Question;
  index: number;
  total: number;
  isLast: boolean;
  onNext: (record: AnswerRecord) => void;
}

/** Una domanda della sessione: intestazione, corpo per tipo, feedback e navigazione. */
export function QuestionView({ question, index, total, isLast, onNext }: Props) {
  const [record, setRecord] = useState<AnswerRecord | null>(null);
  const pct = Math.round((index / total) * 100);

  function handleResult(result: AnswerResult, scored: boolean) {
    setRecord({ questionId: question.id, result, formative: !scored });
  }

  const isComposite =
    question.kind === "caseStudy" || question.kind === "mediaAnalysis";

  return (
    <section className="card fade-in" aria-labelledby="q-prompt">
      <div className="progress">
        <div className="progress__meta">
          <span>
            Domanda {index + 1} di {total}
          </span>
          <span className="kind-tag">
            <Icon name={KIND_ICON[question.kind]} size={15} />
            {kindDisplayName[question.kind]}
          </span>
        </div>
        <div
          className="progress__bar"
          role="progressbar"
          aria-valuenow={index + 1}
          aria-valuemin={1}
          aria-valuemax={total}
          aria-label="Avanzamento del quiz"
        >
          <div className="progress__fill" style={{ width: `${pct}%` }} />
        </div>
      </div>

      <h2 id="q-prompt" className="prompt">
        {question.prompt}
      </h2>

      {isComposite ? (
        <CaseStudyView question={question} onResult={handleResult} />
      ) : (
        <QuestionBody question={question} onResult={handleResult} />
      )}

      <div className="btn-row btn-row--stack" style={{ marginTop: "var(--gap)" }}>
        <button
          className="btn btn--primary btn--block"
          disabled={!record}
          onClick={() => record && onNext(record)}
        >
          {isLast ? "Termina" : "Avanti"} <Icon name="arrow" />
        </button>
      </div>
    </section>
  );
}
