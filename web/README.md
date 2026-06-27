# Quiz – versione web

Versione web statica dell'app quiz iOS, deployabile su **GitHub Pages**.
Riusa gli stessi JSON delle materie dell'app iOS (`quiz_app/Documents/`) come
**unica sorgente di verità**: i dati non sono duplicati nel repo.

- **Stack:** TypeScript + React + Vite, nessun backend/DB/login.
- **Stato:** tenuto solo in memoria durante la sessione del browser (niente persistenza).
- **Logica separata dalla UI:** `src/quiz/` (tipi, valutazione, pool, sessione) è puro;
  `src/components/` è solo presentazione.

## Sviluppo

```bash
cd web
npm install
npm run dev      # http://localhost:5173 (esegue prima sync-data)
npm run build    # typecheck + build in web/dist
npm run preview  # serve la build di produzione
```

`npm run sync-data` copia `quiz_app/Documents/*.json` in `web/public/data/`
(cartella gitignorata) e genera `index.json` con i metadati delle materie.
Gira automaticamente in `predev`/`prebuild`.

## Deploy su GitHub Pages

Il workflow [`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml)
parte sui push verso `main`, installa le dipendenze in `web/`, fa la build e
pubblica `web/dist`.

Per attivarlo: **Settings → Pages → Build and deployment → Source = GitHub Actions**.
Il sito sarà servito da `https://USERNAME.github.io/NOME_REPO/`; il `base: './'`
in `vite.config.ts` rende i percorsi relativi, quindi funziona anche sotto sottocartella.

## Tipi di domanda supportati

| Tipo (Swift `QuestionKind`) | Web | Note |
|---|---|---|
| `multiple` | ✅ valutato | multi-selezione (più risposte corrette) |
| `matching` | ✅ valutato | abbinamento con menu a tendina |
| `trueFalseMotivated` | ✅ valutato | V/F + motivazioni (anche da `optionPool`) |
| `openRubric` / `constructedResponse` con `optionPool` | ✅ valutato | resi come selezione della checklist corretta |
| `openRubric` / `constructedResponse` senza pool | ◐ formativo | mostra risposta modello/criteri, escluso dal punteggio |
| `caseStudy` / `mediaAnalysis` | ✅/◐ | stimoli + sotto-domande atomiche, esito aggregato |
| `clozeWordBank`, `shortAnswer`, `ordered`, `calculation` | ◐ formativo | non interattivi: mostrano la soluzione di riferimento |

## Limiti rispetto all'app iOS

La versione web è **parallela e minimale**; rispetto all'app iOS **non** include:

- **Persistenza e statistiche:** niente storico, ripetizione spaziata (SM-2),
  conteggio errori per categoria, modalità "Errori"/"Ripasso intelligente".
- **Modalità studio/Teoria:** il campo `theory` dei JSON viene ignorato
  (niente notebook, modalità guidata Teoria→Quiz, difficoltà progressiva).
- **Scaglioni da `config`:** la scelta del numero di domande è una selezione fissa
  (10/20/50/tutte), non legge `scales_*` dal JSON.
- **Import/validazione file, widget, notifiche, impostazioni.**
- **Tipi non interattivi** (cloze, riordino, calcolo, risposte aperte senza pool):
  resi come schede formative di sola consultazione, esclusi dal punteggio.
- **Media** (`MediaAsset`): non renderizzati (placeholder testuale).
- **Campionamento del pool:** equivalente a quello iOS ma con RNG non deterministico
  (nessun seed), quindi le opzioni mostrate variano a ogni tentativo.
