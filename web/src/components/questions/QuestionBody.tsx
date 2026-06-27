import type { Question } from "../../quiz/types";
import type { AnswerResult } from "../../quiz/evaluate";
import { MultipleChoice } from "./MultipleChoice";
import { Matching } from "./Matching";
import { TrueFalse } from "./TrueFalse";
import { PoolQuestion } from "./PoolQuestion";
import { FormativeCard } from "./FormativeCard";

interface Props {
  question: Question;
  onResult: (result: AnswerResult, scored: boolean) => void;
}

/** Dispatch al renderer giusto per una domanda atomica. */
export function QuestionBody({ question, onResult }: Props) {
  switch (question.kind) {
    case "multiple":
      return <MultipleChoice question={question} onResult={onResult} />;
    case "matching":
      return <Matching question={question} onResult={onResult} />;
    case "trueFalseMotivated":
      return <TrueFalse question={question} onResult={onResult} />;
    case "openRubric":
    case "constructedResponse":
      return question.optionPool ? (
        <PoolQuestion question={question} onResult={onResult} />
      ) : (
        <FormativeCard question={question} onResult={onResult} />
      );
    default:
      // cloze, shortAnswer, ordered, calculation, ecc.: scheda formativa.
      return <FormativeCard question={question} onResult={onResult} />;
  }
}
