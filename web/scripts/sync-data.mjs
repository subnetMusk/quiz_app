// Copia i JSON delle materie condivisi (quiz_app/Documents) dentro web/public/data,
// generando anche un index.json con i metadati. Eseguito da `predev`/`prebuild`.
// Sorgente unica di verità: i JSON iOS NON vengono duplicati nel repo (public/data è gitignorata).

import { mkdir, readdir, readFile, writeFile, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = resolve(__dirname, "../../quiz_app/Documents");
const OUT = resolve(__dirname, "../public/data");

function summarizeKinds(questions) {
  const counts = {};
  for (const q of questions ?? []) {
    const k = q?.kind ?? "unknown";
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return counts;
}

async function main() {
  if (!existsSync(SRC)) {
    console.error(`[sync-data] Cartella sorgente non trovata: ${SRC}`);
    process.exit(1);
  }

  // Reset pulito della cartella di output.
  await rm(OUT, { recursive: true, force: true });
  await mkdir(OUT, { recursive: true });

  const files = (await readdir(SRC)).filter((f) => f.endsWith(".json"));
  const subjects = [];

  for (const file of files) {
    const raw = await readFile(join(SRC, file), "utf8");
    let data;
    try {
      data = JSON.parse(raw);
    } catch (err) {
      console.warn(`[sync-data] JSON non valido, salto ${file}: ${err.message}`);
      continue;
    }
    const id = file.replace(/\.json$/, "");
    // Copia verbatim (sorgente di verità condivisa con iOS).
    await writeFile(join(OUT, file), raw);
    subjects.push({
      id,
      file,
      name: data?.meta?.subject_name ?? id,
      version: data?.meta?.version ?? null,
      questionCount: Array.isArray(data?.questions) ? data.questions.length : 0,
      kinds: summarizeKinds(data?.questions),
      hasTheory: Array.isArray(data?.theory) && data.theory.length > 0,
    });
  }

  subjects.sort((a, b) => a.name.localeCompare(b.name, "it"));
  await writeFile(
    join(OUT, "index.json"),
    JSON.stringify({ generatedAt: new Date().toISOString(), subjects }, null, 2)
  );

  console.log(`[sync-data] ${subjects.length} materie copiate in public/data`);
}

main().catch((err) => {
  console.error("[sync-data] errore:", err);
  process.exit(1);
});
