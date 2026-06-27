// Caricamento dell'indice materie e dei singoli JSON (generati in public/data da sync-data).

import type { Materia, SubjectIndex } from "./types";

// BASE_URL gestisce il deploy sotto sottocartella (GitHub Pages: /NOME_REPO/).
const base = import.meta.env.BASE_URL;

async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${base}data/${path}`, { cache: "no-cache" });
  if (!res.ok) {
    throw new Error(`Impossibile caricare ${path} (HTTP ${res.status})`);
  }
  return (await res.json()) as T;
}

export function loadIndex(): Promise<SubjectIndex> {
  return fetchJson<SubjectIndex>("index.json");
}

export function loadSubject(file: string): Promise<Materia> {
  return fetchJson<Materia>(file);
}
