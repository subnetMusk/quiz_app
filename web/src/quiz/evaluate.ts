// Valutazione delle domande (port da Evaluator.swift). Logica pura, senza UI.

import type { Option, Question } from "./types";

export type AnswerResult = "correct" | "incomplete" | "wrong";

export interface MultipleDetail {
  result: AnswerResult;
  missedCorrect: number[]; // corrette non selezionate
  wrongPicked: number[]; // errate selezionate
}

/** Valuta una domanda multiple in base alle opzioni selezionate. */
export function evaluateMultiple(
  question: Question,
  selected: Set<number>
): MultipleDetail {
  const opts = question.options ?? [];
  const correct = new Set(opts.filter((o) => o.isCorrect).map((o) => o.id));
  const wrong = new Set(opts.filter((o) => !o.isCorrect).map((o) => o.id));

  const missed = [...correct].filter((id) => !selected.has(id)).sort((a, b) => a - b);
  const wrongSel = [...selected].filter((id) => wrong.has(id)).sort((a, b) => a - b);

  let result: AnswerResult;
  const isExact =
    selected.size === correct.size && [...selected].every((id) => correct.has(id));
  if (wrongSel.length) result = "wrong";
  else if (isExact) result = "correct";
  else if (selected.size === 0) result = "wrong";
  else result = "incomplete";

  return { result, missedCorrect: missed, wrongPicked: wrongSel };
}

/** Valuta una domanda matching. `userPairs`: indice-sinistra -> indice-destra. */
export function evaluateMatching(
  question: Question,
  userPairs: Record<number, number>
): AnswerResult {
  const gold = question.correctMatches;
  if (!gold || Object.keys(gold).length === 0) return "correct";

  const pairs = Object.entries(userPairs);
  if (pairs.length === 0) return "wrong";

  for (const [l, r] of pairs) {
    if (gold[l] !== r) return "wrong";
  }
  return pairs.length === Object.keys(gold).length ? "correct" : "incomplete";
}

/**
 * Valuta una motivazione (lista statica `motivationOptions`) come una scelta multipla.
 * Per le domande con `optionPool` usare invece evaluatePoolSelection (pool.ts).
 */
export function evaluateMotivationOptions(
  options: Option[],
  selected: Set<number>
): AnswerResult {
  if (options.length === 0) return "correct";
  const correct = new Set(options.filter((o) => o.isCorrect).map((o) => o.id));
  const wrong = new Set(options.filter((o) => !o.isCorrect).map((o) => o.id));
  if ([...selected].some((id) => wrong.has(id))) return "wrong";
  const isExact =
    selected.size === correct.size && [...selected].every((id) => correct.has(id));
  if (isExact) return "correct";
  if (selected.size === 0) return "wrong";
  return "incomplete";
}

/** Aggrega i risultati delle sotto-domande di un caso (mirror di aggregateResults). */
export function aggregateResults(results: AnswerResult[]): AnswerResult {
  if (results.length === 0) return "incomplete";
  const correct = results.filter((r) => r === "correct").length;
  const wrong = results.filter((r) => r === "wrong").length;
  if (correct === results.length) return "correct";
  if (wrong === results.length) return "wrong";
  return "incomplete";
}

/**
 * `true` se la domanda è puramente formativa (non concorre al punteggio).
 * Mirror semplificato di Question.isFormative: openRubric/constructedResponse senza
 * optionPool restano formativi; un caso/media è formativo se tutte le sub lo sono.
 */
export function isFormative(q: Question): boolean {
  if (q.kind === "openRubric" || q.kind === "constructedResponse") {
    return q.optionPool == null;
  }
  if (q.kind === "caseStudy" || q.kind === "mediaAnalysis") {
    const subs = q.subquestions ?? [];
    return subs.length === 0 ? true : subs.every(isFormative);
  }
  return false;
}

/** Tipi che la web app sa rendere in modo interattivo e valutabile. */
const INTERACTIVE_KINDS = new Set<Question["kind"]>([
  "multiple",
  "matching",
  "trueFalseMotivated",
]);

/** `true` se la domanda è interattiva nella web app (atomica o caso con sub interattive). */
export function isInteractive(q: Question): boolean {
  if (INTERACTIVE_KINDS.has(q.kind)) return true;
  if (q.kind === "caseStudy" || q.kind === "mediaAnalysis") {
    return (q.subquestions ?? []).some(isInteractive);
  }
  return false;
}
