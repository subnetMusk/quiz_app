// Tipi TypeScript coerenti con i model Swift (MateriaModels.swift).
// I JSON delle materie sono condivisi con l'app iOS: questi tipi ne descrivono lo schema.

export type QuestionKind =
  | "multiple"
  | "matching"
  | "trueFalseMotivated"
  | "clozeWordBank"
  | "shortAnswer"
  | "ordered"
  | "calculation"
  | "openRubric"
  | "constructedResponse"
  | "mediaAnalysis"
  | "caseStudy";

/** Nome leggibile del tipo di domanda (mirror di QuestionKind.displayName). */
export const kindDisplayName: Record<QuestionKind, string> = {
  multiple: "Scelta multipla",
  matching: "Abbinamento",
  trueFalseMotivated: "Vero/Falso motivato",
  clozeWordBank: "Testo bucato",
  shortAnswer: "Risposta breve",
  ordered: "Riordino",
  calculation: "Calcolo",
  openRubric: "Risposta aperta",
  constructedResponse: "Produzione guidata",
  mediaAnalysis: "Analisi di un media",
  caseStudy: "Caso di studio",
};

export interface Option {
  id: number;
  text: string;
  isCorrect: boolean;
}

export interface PoolEntry {
  id: string;
  text: string;
  isCorrect: boolean;
  canonicalPointId: string;
  variantKind?: string;
  explanation?: string;
}

export interface CountRange {
  min: number;
  max: number;
}

export interface AnswerOptionPool {
  displayCount: number;
  correctCountRange: CountRange;
  entries: PoolEntry[];
  allowDuplicateConcepts?: boolean;
}

export interface MediaAsset {
  type: "image" | "audio" | "video" | "document";
  url?: string;
  asset?: string;
  alt?: string;
  caption?: string;
}

export interface Stimulus {
  id: string;
  title?: string;
  text?: string;
  code?: string;
  media?: MediaAsset;
}

export interface Question {
  id: string;
  category: string;
  subcategory?: string;
  kind: QuestionKind;
  primary?: boolean;
  sectionId?: string;
  difficulty?: number;
  prompt: string;
  code?: string;
  explanation?: string;
  // multiple
  options?: Option[];
  // matching
  left?: string[];
  right?: string[];
  correctMatches?: Record<string, number>; // chiavi indice-stringa nel JSON
  // trueFalseMotivated
  answer?: boolean;
  motivationOptions?: Option[];
  wrongAnswerExplanation?: string;
  // clozeWordBank
  text?: string;
  blanks?: { id: number; answers: string[] }[];
  wordBank?: string[];
  // shortAnswer / calculation
  acceptedAnswers?: string[];
  caseSensitive?: boolean;
  givens?: string[];
  answerFormat?: string;
  tolerance?: number;
  expectedSteps?: string[];
  // ordered
  items?: string[];
  // openRubric
  expectedAnswer?: string;
  keyPoints?: string[];
  minKeyPoints?: number;
  commonMistakes?: string[];
  showRubricAfter?: boolean;
  // constructedResponse
  requiredCriteria?: string[];
  optionalCriteria?: string[];
  blockingErrors?: string[];
  sampleSolution?: string;
  // mediaAnalysis
  media?: MediaAsset;
  // caseStudy / mediaAnalysis (compositi)
  stimuli?: Stimulus[];
  subquestions?: Question[];
  // pool randomizzato (precede le liste statiche legacy)
  optionPool?: AnswerOptionPool;
}

export interface TaxonomyNode {
  id: string;
  name: string;
  sub?: TaxonomyNode[];
}

export interface Materia {
  meta: { subject_id: string; subject_name: string; version: number };
  config?: { feedback?: string };
  taxonomy: TaxonomyNode[];
  questions: Question[];
  theory?: unknown[];
}

/** Voce dell'indice generato da scripts/sync-data.mjs. */
export interface SubjectIndexEntry {
  id: string;
  file: string;
  name: string;
  version: number | null;
  questionCount: number;
  kinds: Partial<Record<QuestionKind, number>>;
  hasTheory: boolean;
}

export interface SubjectIndex {
  generatedAt: string;
  subjects: SubjectIndexEntry[];
}

// MARK: - Helper dominio (mirror di MateriaModels.swift)

/** Nome leggibile di categoria/sottocategoria a partire dalla tassonomia. */
export function displayCategory(
  m: Materia,
  categoryId: string,
  subId?: string
): string {
  const cat = m.taxonomy.find((n) => n.id === categoryId);
  if (!cat) return categoryId;
  if (subId) {
    const s = cat.sub?.find((n) => n.id === subId);
    if (s) return `${cat.name} · ${s.name}`;
  }
  return cat.name;
}
