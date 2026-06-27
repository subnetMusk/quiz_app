// Costruzione e riepilogo di una sessione di quiz. Logica pura, stato tenuto in memoria
// dal componente React (nessuna persistenza, come da requisiti).

import type { Materia, Question } from "./types";
import type { AnswerResult } from "./evaluate";
import { isFormative } from "./evaluate";

export interface SessionOptions {
  /** Numero massimo di domande (undefined = tutte). */
  limit?: number;
  /** Filtra per categoria (id tassonomia). undefined = tutte. */
  categoryId?: string;
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Seleziona e mescola le domande per la sessione. */
export function buildQuestions(m: Materia, opts: SessionOptions = {}): Question[] {
  let pool = m.questions;
  if (opts.categoryId) pool = pool.filter((q) => q.category === opts.categoryId);
  const shuffled = shuffle(pool);
  return opts.limit ? shuffled.slice(0, opts.limit) : shuffled;
}

/** Risposta registrata per una domanda della sessione. */
export interface AnswerRecord {
  questionId: string;
  result: AnswerResult;
  /** true se la domanda è formativa (esclusa dal punteggio). */
  formative: boolean;
}

export interface SessionSummary {
  total: number;
  scored: number; // domande che concorrono al punteggio (non formative)
  correct: number;
  incomplete: number;
  wrong: number;
  formative: number;
  /** Percentuale di corrette sulle valutabili (0 se nessuna valutabile). */
  scorePercent: number;
}

export function summarize(records: AnswerRecord[]): SessionSummary {
  const scoredRecords = records.filter((r) => !r.formative);
  const correct = scoredRecords.filter((r) => r.result === "correct").length;
  const incomplete = scoredRecords.filter((r) => r.result === "incomplete").length;
  const wrong = scoredRecords.filter((r) => r.result === "wrong").length;
  const scored = scoredRecords.length;
  return {
    total: records.length,
    scored,
    correct,
    incomplete,
    wrong,
    formative: records.length - scored,
    scorePercent: scored ? Math.round((correct / scored) * 100) : 0,
  };
}

/** Comodo: marca una domanda come formativa o no. */
export function questionIsFormative(q: Question): boolean {
  return isFormative(q);
}
