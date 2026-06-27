// Port (compatto ma fedele) di PoolSampler da Evaluator.swift.
// Campiona un sottoinsieme di opzioni da un AnswerOptionPool rispettando il range di
// corrette e l'unicità dei concetti (canonicalPointId). Usato dalle domande con optionPool.

import type { AnswerOptionPool, PoolEntry } from "./types";
import type { AnswerResult } from "./evaluate";

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function pickRandom<T>(arr: T[]): T | undefined {
  return arr.length ? arr[Math.floor(Math.random() * arr.length)] : undefined;
}

interface Capacity {
  onlyCorrect: string[];
  onlyWrong: string[];
  both: string[];
  correctEntries: Record<string, PoolEntry[]>;
  wrongEntries: Record<string, PoolEntry[]>;
}

function classify(pool: AnswerOptionPool): Capacity {
  const cap: Capacity = {
    onlyCorrect: [],
    onlyWrong: [],
    both: [],
    correctEntries: {},
    wrongEntries: {},
  };
  const byConcept: Record<string, PoolEntry[]> = {};
  for (const e of pool.entries) {
    (byConcept[e.canonicalPointId] ??= []).push(e);
  }
  for (const [concept, entries] of Object.entries(byConcept)) {
    const corrects = entries.filter((e) => e.isCorrect);
    const wrongs = entries.filter((e) => !e.isCorrect);
    if (corrects.length) cap.correctEntries[concept] = corrects;
    if (wrongs.length) cap.wrongEntries[concept] = wrongs;
    if (corrects.length && !wrongs.length) cap.onlyCorrect.push(concept);
    else if (!corrects.length && wrongs.length) cap.onlyWrong.push(concept);
    else if (corrects.length && wrongs.length) cap.both.push(concept);
  }
  return cap;
}

/** Valori di k (numero di corrette mostrate) ammissibili. */
export function feasibleCorrectCounts(pool: AnswerOptionPool): number[] {
  const d = pool.displayCount;
  const r = pool.correctCountRange;
  if (!(d > 0 && r.min >= 0 && r.max >= r.min)) return [];

  const range: number[] = [];
  for (let k = Math.max(0, r.min); k <= Math.min(r.max, d); k++) range.push(k);

  if (pool.allowDuplicateConcepts === true) {
    const nCorrect = pool.entries.filter((e) => e.isCorrect).length;
    const nWrong = pool.entries.filter((e) => !e.isCorrect).length;
    return range.filter((k) => k <= nCorrect && d - k <= nWrong);
  }

  const cap = classify(pool);
  const oc = cap.onlyCorrect.length;
  const ow = cap.onlyWrong.length;
  const b = cap.both.length;
  const cc = oc + b;
  const wc = ow + b;
  return range.filter((k) => {
    const w = d - k;
    if (!(k <= cc && w <= wc)) return false;
    const needBothForCorrect = Math.max(0, k - oc);
    const needBothForWrong = Math.max(0, w - ow);
    return needBothForCorrect + needBothForWrong <= b;
  });
}

/** Campiona displayCount entry, o null se il pool è infeasible. */
export function samplePool(pool: AnswerOptionPool): PoolEntry[] | null {
  const feasible = feasibleCorrectCounts(pool);
  const k = pickRandom(feasible);
  if (k === undefined) return null;
  const d = pool.displayCount;

  if (pool.allowDuplicateConcepts === true) {
    const corrects = shuffle(pool.entries.filter((e) => e.isCorrect));
    const wrongs = shuffle(pool.entries.filter((e) => !e.isCorrect));
    if (corrects.length < k || wrongs.length < d - k) return null;
    return shuffle([...corrects.slice(0, k), ...wrongs.slice(0, d - k)]);
  }

  const cap = classify(pool);
  const chosen = new Set<string>();
  const result: PoolEntry[] = [];

  const correctSources = [...shuffle(cap.onlyCorrect), ...shuffle(cap.both)];
  for (const concept of correctSources) {
    if (result.filter((e) => e.isCorrect).length >= k) break;
    if (chosen.has(concept)) continue;
    const entry = pickRandom(cap.correctEntries[concept] ?? []);
    if (!entry) continue;
    chosen.add(concept);
    result.push(entry);
  }
  if (result.length !== k) return null;

  const wrongSources = [...shuffle(cap.onlyWrong), ...shuffle(cap.both)];
  for (const concept of wrongSources) {
    if (result.length >= d) break;
    if (chosen.has(concept)) continue;
    const entry = pickRandom(cap.wrongEntries[concept] ?? []);
    if (!entry) continue;
    chosen.add(concept);
    result.push(entry);
  }
  if (result.length !== d) return null;

  return shuffle(result);
}

export interface PoolEvalDetail {
  result: AnswerResult;
  missedConcepts: string[];
  wrongConcepts: string[];
}

/** Valuta la selezione considerando SOLO le entry mostrate (mirror di evaluatePoolSelection). */
export function evaluatePoolSelection(
  shown: PoolEntry[],
  selected: Set<string>
): PoolEvalDetail {
  const correct = shown.filter((e) => e.isCorrect);
  const correctIds = new Set(correct.map((e) => e.id));
  const shownIds = new Set(shown.map((e) => e.id));
  const effective = new Set([...selected].filter((id) => shownIds.has(id)));

  const wrongSelected = shown.filter((e) => !e.isCorrect && effective.has(e.id));
  const missed = correct.filter((e) => !effective.has(e.id));

  let result: AnswerResult;
  const sameAsCorrect =
    effective.size === correctIds.size &&
    [...effective].every((id) => correctIds.has(id));
  if (wrongSelected.length) result = "wrong";
  else if (sameAsCorrect && correctIds.size) result = "correct";
  else if (effective.size === 0) result = "wrong";
  else result = "incomplete";

  return {
    result,
    missedConcepts: missed.map((e) => e.canonicalPointId).sort(),
    wrongConcepts: wrongSelected.map((e) => e.canonicalPointId).sort(),
  };
}
