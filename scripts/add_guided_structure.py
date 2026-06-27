#!/usr/bin/env python3
# coding: utf-8
"""
WS2 — Struttura per la modalità di studio guidata su tecweb_completo.json.
- Definisce sezioni ordinate (generale -> specifico) per ogni categoria.
- Assegna a ogni domanda `sectionId` (per keyword sul prompt) e `difficulty` (per tipo).
- Genera un body-seed per ogni sezione (verrà riscritto in prosa da Codex).
Idempotente: rigenera sectionId/difficulty/sections a ogni esecuzione.
"""
import json, sys, re
from collections import defaultdict, OrderedDict

PATH = "quiz_app/Documents/tecweb_completo.json"

# Sezioni per categoria: lista ordinata di (sectionId, titolo, summary, [keyword]).
# La PRIMA sezione è anche il fallback per le domande non matchate.
SECTIONS = {
    "http_web": [
        ("s_http_metodi", "Metodi HTTP: GET e POST", "Semantica, parametri e usi di GET e POST.",
         ["get", "post", "metodo", "query string", "form"]),
        ("s_http_serverclient", "Server side vs client side", "Dove gira il codice e che ruolo ha.",
         ["server side", "client side", "lato server", "lato client", "linguaggio server"]),
        ("s_http_validazione", "Validazione dei dati", "Limiti delle regex nella validazione.",
         ["regex", "espressione regolare", "quantificator", "validare", "@"]),
    ],
    "markup_dom": [
        ("s_md_markup", "Linguaggi di markup", "Cos'è il markup e le sue caratteristiche.",
         ["markup"]),
        ("s_md_xhtml", "Regole di XHTML", "Sintassi rigorosa di XHTML.",
         ["xhtml", "self-closing", "chiusura", "input", "<img"]),
        ("s_md_dom", "DOM, meta e comportamento", "DOM, metadati e JavaScript nel documento.",
         ["dom", "document object model", "meta", "javascript", "ereditar", "html5"]),
    ],
    "xml_dtd_xsd_xpath": [
        ("s_xml_base", "XML: sintassi di base", "Elementi, sintassi ed equivalenze in XML.",
         ["xml", "element", "elemento vuoto"]),
        ("s_xml_dtd_xsd", "DTD e XMLSchema", "Definire schemi: DTD vs XMLSchema, namespace, tipi.",
         ["dtd", "xmlschema", "schema", "namespace", "duration", "elementformdefault", "qualified",
          "tcorso", "tpubblicazione", "pizze", "libro", "prodotto"]),
        ("s_xml_xpath", "XPath", "Selezionare nodi con XPath.",
         ["xpath", "/viaggio", "espressione xpath"]),
    ],
    "css_cascade": [
        ("s_css_cascata", "Cascata e ordine", "Come l'ordine determina lo stile applicato.",
         ["ordine", "cascata", "priorità", "ultima", "applicazione degli stili"]),
        ("s_css_specificita", "Specificità", "Calcolo della specificità dei selettori.",
         ["specificità", "specific", "id", "classe", "selettore", "colore finale", "th", "sfondo"]),
        ("s_css_important", "La regola !important", "Effetto e limiti di !important.",
         ["!important", "important"]),
    ],
    "information_architecture": [
        ("s_ia_schemi", "Schemi organizzativi", "Schemi esatti e ambigui e quando usarli.",
         ["schema organizzativ", "schemi organizzativ", "schema esatto", "schema ambiguo",
          "schema adatto", "schemi ambigui"]),
        ("s_ia_struttura", "Strutture e gerarchie", "Gerarchie, profondità, larghezza, layout.",
         ["gerarch", "struttura organizzativa", "profond", "larghezza", "menu", "voci",
          "schede", "layout"]),
        ("s_ia_navigazione", "Navigazione e orientamento", "Convenzioni, disorientamento, above the fold.",
         ["convenzion", "disorientamento", "path", "above the fold", "area sicura", "pesca",
          "domande fondamentali", "sovraccarico"]),
    ],
    "accessibility": [
        ("s_a11y_fondamenti", "Fondamenti e test", "Definizione, WCAG, test, colori e menu.",
         ["definisci l'accessibilità", "wcag", "test", "validazione html", "screen reader",
          "colori", "menu a scomparsa", "tendina", "divisione tra contenuto"]),
        ("s_a11y_tabelle", "Tabelle accessibili", "Quando e come usare tabelle accessibili.",
         ["tabell"]),
        ("s_a11y_link_immagini", "Link, immagini e testo", "Link, alt text, contrasto e linguaggio.",
         ["link", "alt", "immagin", "icone", "bandiere", "contrasto", "font", "mail",
          "grafico", "logo", "aria-label"]),
    ],
    "seo": [
        ("s_seo_separazione", "Separazione e SEO", "Separare contenuto/presentazione/comportamento.",
         ["divisione", "separazione", "separare", "contenuto e presentazione",
          "struttura/contenuto", "comportamento"]),
        ("s_seo_metatag", "Metatag e title", "Metatag e tag title per la SERP.",
         ["metatag", "metatag", "title", "description", "author", "keywords", "serp"]),
    ],
    "responsive_mobile": [
        ("s_rm_principi", "Mobile e responsive", "Progettare per il mobile e layout responsive.",
         ["mobile", "breakpoint", "responsive", "pollice"]),
    ],
    "emotional_design": [
        ("s_ed_definizione", "Cos'è l'emotional design", "Oltre l'estetica: definizione e scopo.",
         ["definisci l'emotional", "non coincide", "estetica"]),
        ("s_ed_livelli", "I livelli di Norman", "Viscerale, comportamentale e riflessivo.",
         ["viscerale", "comportamentale", "riflessivo", "norman", "livello", "livelli"]),
    ],
}

# Override curati per domande ambigue (la keyword sbaglierebbe la sezione).
OVERRIDES = {
    "tw115": "s_css_cascata",   # "ordine di applicazione degli stili con/senza !important"
    "tw116": "s_css_cascata",   # "ordine di priorità delle regole con/senza !important"
}

DIFFICULTY_BY_KIND = {
    "trueFalseMotivated": 1,
    "openRubric": 2,
    "constructedResponse": 3,
    "caseStudy": 3,
}

def assign_section(cat, prompt):
    rules = SECTIONS.get(cat)
    if not rules:
        return None
    p = prompt.lower()
    # Match dalla sezione più specifica (ultima in ordine di display) alla più generale,
    # così le keyword generiche (es. "xml") non rubano le domande specifiche.
    for sid, _title, _sum, keywords in reversed(rules):
        if any(k in p for k in keywords):
            return sid
    return rules[0][0]  # fallback: prima sezione (la più generale)

def main():
    data = json.load(open(PATH, encoding="utf-8"))
    questions = data["questions"]

    # 1) sectionId + difficulty per domanda
    by_section = defaultdict(list)
    for q in questions:
        cat = q["category"]
        sid = OVERRIDES.get(q["id"]) or assign_section(cat, q.get("prompt", ""))
        if sid:
            q["sectionId"] = sid
        q["difficulty"] = DIFFICULTY_BY_KIND.get(q["kind"], 2)
        if sid:
            by_section[(cat, sid)].append(q)

    # 2) sezioni con body-seed nei notebook teoria
    notes = {t["categoryId"]: t for t in data.get("theory", [])}
    for cat, rules in SECTIONS.items():
        note = notes.get(cat)
        if not note:
            continue
        sections = []
        for sid, title, summary, _kw in rules:
            qs = sorted(by_section.get((cat, sid), []), key=lambda q: q.get("difficulty", 2))
            body = build_seed_body(title, summary, qs)
            sections.append(OrderedDict([
                ("id", sid), ("title", title), ("summary", summary), ("body", body),
            ]))
        note["sections"] = sections
        if not note.get("intro"):
            note["intro"] = f"Percorso guidato su **{note.get('title', cat)}**: leggi ogni sezione e mettiti subito alla prova con domande di difficoltà crescente."

    json.dump(data, open(PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    # report
    print("OK. Domande:", len(questions))
    for cat, rules in SECTIONS.items():
        for sid, title, *_ in rules:
            print(f"  {cat}/{sid}: {len(by_section.get((cat,sid),[]))} domande")

def build_seed_body(title, summary, qs):
    """Body-seed (placeholder, da riscrivere in prosa da Codex): titolo + punti chiave dedotti."""
    lines = [f"## {title}", "", summary or "", ""]
    seen = set()
    bullets = []
    for q in qs:
        for kp in (q.get("keyPoints") or []):
            k = kp.strip()
            if k and k.lower() not in seen:
                seen.add(k.lower()); bullets.append(k)
        ea = (q.get("expectedAnswer") or "").strip()
        if ea and ea.lower() not in seen:
            seen.add(ea.lower()); bullets.append(ea)
    if not bullets:
        bullets = ["Contenuto in preparazione."]
    lines += [f"- {b}" for b in bullets[:12]]
    return "\n".join(lines).strip()

if __name__ == "__main__":
    main()
