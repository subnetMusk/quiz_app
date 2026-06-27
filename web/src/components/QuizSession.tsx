import { useMemo, useState } from "react";
import type { Materia } from "../quiz/types";
import type { AnswerRecord, SessionOptions } from "../quiz/session";
import { buildQuestions } from "../quiz/session";
import { QuestionView } from "./QuestionView";
import { Summary } from "./Summary";

interface Props {
  materia: Materia;
  options: SessionOptions;
  /** Cambiando questa chiave la sessione viene ricostruita da zero. */
  sessionKey: number;
  onBackToSubjects: () => void;
  onRestart: () => void;
}

/** Orchestratore della sessione: scorre le domande e mostra il riepilogo. */
export function QuizSession({
  materia,
  options,
  sessionKey,
  onBackToSubjects,
  onRestart,
}: Props) {
  const questions = useMemo(
    () => buildQuestions(materia, options),
    // sessionKey forza un nuovo set di domande mescolate.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [materia, options, sessionKey]
  );

  const [idx, setIdx] = useState(0);
  const [records, setRecords] = useState<AnswerRecord[]>([]);
  const [finished, setFinished] = useState(false);

  if (questions.length === 0) {
    return (
      <div className="notice notice--error" role="alert">
        <p>Nessuna domanda disponibile per questa selezione.</p>
        <button className="btn" onClick={onBackToSubjects}>
          Torna alle materie
        </button>
      </div>
    );
  }

  if (finished) {
    return (
      <Summary
        subjectName={materia.meta.subject_name}
        records={records}
        onRestart={onRestart}
        onBackToSubjects={onBackToSubjects}
      />
    );
  }

  function handleNext(record: AnswerRecord) {
    const updated = [...records, record];
    setRecords(updated);
    if (idx + 1 >= questions.length) setFinished(true);
    else setIdx(idx + 1);
  }

  const q = questions[idx];
  return (
    <QuestionView
      // key garantisce il reset dello stato interno a ogni domanda.
      key={`${sessionKey}-${q.id}-${idx}`}
      question={q}
      index={idx}
      total={questions.length}
      isLast={idx + 1 >= questions.length}
      onNext={handleNext}
    />
  );
}
