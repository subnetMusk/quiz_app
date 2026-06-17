#!/usr/bin/env python3
"""Clean TecWeb data and add theory/primary metadata.

This is a deterministic one-shot migration for quiz_app/Documents/tecweb_completo.json.
It intentionally derives theory notes from existing prompts, explanations, key points,
criteria, and option pools instead of introducing unanchored content.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
TECWEB = ROOT / "quiz_app" / "Documents" / "tecweb_completo.json"

FRAMING_PREFIXES = (
    "La formulazione sostiene che ",
    "Il punto da valutare è che ",
    "La formulazione descrive ",
    "La formulazione afferma che ",
)

PRIMARY_BY_CATEGORY = {
    "http_web": {"tw001", "tw002", "tw006", "tw007", "tw061"},
    "markup_dom": {"tw004", "tw005", "tw064", "tw068"},
    "xml_dtd_xsd_xpath": {"tw066", "tw070", "tw072", "tw073", "tw095"},
    "css_cascade": {"tw115", "tw116", "tw117", "tw121", "tw122"},
    "information_architecture": {"tw008", "tw013", "tw014", "tw020", "tw022", "tw024", "tw026", "tw112"},
    "responsive_mobile": {"tw027", "tw028", "tw029"},
    "accessibility": {"tw030", "tw031", "tw032", "tw035", "tw036", "tw039", "tw040", "tw044", "tw054", "tw056", "tw059"},
    "seo": {"tw096", "tw097", "tw099", "tw102", "tw106", "tw107", "tw109", "tw110"},
}


def ucfirst_first_alpha(text: str) -> str:
    text = text.strip()
    if not text:
        return text
    if text.startswith("!Important"):
        return text.replace("!Important", "!important", 1)
    if text[0].isalpha():
        return f"{text[0].upper()}{text[1:]}"
    if text[0] in "\"'“‘(":
        for i, char in enumerate(text):
            if char.isalpha():
                return f"{text[:i]}{char.upper()}{text[i + 1:]}"
    return text


def direct_text(text: str) -> str:
    out = text
    for prefix in FRAMING_PREFIXES:
        if out.startswith(prefix):
            out = out[len(prefix) :]
            break
    return ucfirst_first_alpha(out)


def sentence(text: str) -> str:
    out = ucfirst_first_alpha(text)
    if out and out[-1] not in ".?!:;":
        out += "."
    return out


def unique_by(items: list[dict[str, Any]], key: str) -> list[dict[str, Any]]:
    seen: set[str] = set()
    result: list[dict[str, Any]] = []
    for item in items:
        value = str(item.get(key, ""))
        if value and value not in seen:
            seen.add(value)
            result.append(item)
    return result


def option_entries(question: dict[str, Any], is_correct: bool) -> list[dict[str, Any]]:
    entries = question.get("optionPool", {}).get("entries", [])
    return unique_by([entry for entry in entries if entry.get("isCorrect") is is_correct], "canonicalPointId")


def clean_question(question: dict[str, Any], primary_ids: set[str]) -> None:
    if question.get("id") in primary_ids:
        question["primary"] = True
    else:
        question.pop("primary", None)

    for entry in question.get("optionPool", {}).get("entries", []):
        if isinstance(entry.get("text"), str):
            entry["text"] = direct_text(entry["text"])

    for sub in question.get("subquestions", []) or []:
        clean_question(sub, primary_ids)


def points_for(question: dict[str, Any]) -> list[str]:
    points: list[str] = []
    for key in ("keyPoints", "requiredCriteria", "optionalCriteria", "expectedSteps"):
        points.extend(question.get(key, []) or [])

    if question.get("explanation"):
        points.insert(0, question["explanation"])
    elif question.get("expectedAnswer"):
        points.insert(0, question["expectedAnswer"])

    for entry in option_entries(question, True):
        points.append(entry.get("explanation") or entry.get("text", ""))

    return compact_unique(points)


def mistakes_for(question: dict[str, Any]) -> list[str]:
    mistakes: list[str] = []
    for key in ("commonMistakes", "blockingErrors"):
        mistakes.extend(question.get(key, []) or [])
    for entry in option_entries(question, False):
        mistakes.append(entry.get("text", ""))
    return compact_unique(mistakes)


def compact_unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        value = direct_text(str(item))
        if not value:
            continue
        normalized = " ".join(value.lower().split())
        if normalized in seen:
            continue
        seen.add(normalized)
        result.append(value)
    return result


def prose_list(items: list[str], limit: int) -> str:
    return " ".join(sentence(item) for item in items[:limit])


def question_theory(question: dict[str, Any]) -> str:
    parts = [f"## {question['prompt']}"]

    if question.get("kind") == "trueFalseMotivated" and "answer" in question:
        verdict = "vera" if question["answer"] else "falsa"
        parts.append(f"**Idea guida.** La formulazione va considerata **{verdict}** nel contesto del corso.")
    elif question.get("expectedAnswer"):
        parts.append(f"**Idea guida.** {sentence(question['expectedAnswer'])}")
    elif question.get("sampleSolution"):
        parts.append(f"**Idea guida.** {sentence(question['sampleSolution'])}")

    points = points_for(question)
    if points:
        parts.append(f"**Punti da fissare.** {prose_list(points, 4)}")

    mistakes = mistakes_for(question)
    if mistakes:
        parts.append(f"**Errori da evitare.** {prose_list(mistakes, 3)}")

    return "\n\n".join(parts)


def build_theory_note(node: dict[str, Any], questions: list[dict[str, Any]], primary_ids: set[str]) -> dict[str, Any] | None:
    primary_questions = [q for q in questions if q.get("id") in primary_ids]
    selected = primary_questions or questions[: min(3, len(questions))]
    if not selected:
        return None

    intro = (
        f"# {node['name']}\n\n"
        "Questa scheda raccoglie i punti da ripassare prima del quiz mirato. "
        "Le spiegazioni sono ricavate dalle risposte attese, dai punti chiave e dagli errori comuni già presenti nei dati."
    )
    body = "\n\n".join([intro] + [question_theory(q) for q in selected])
    words = len(body.split())
    minutes = max(2, math.ceil(words / 180))

    return {
        "categoryId": node["id"],
        "title": node["name"],
        "body": body,
        "estimatedMinutes": minutes,
    }


def main() -> None:
    data = json.loads(TECWEB.read_text(encoding="utf-8"))
    primary_ids = set().union(*PRIMARY_BY_CATEGORY.values())

    for question in data["questions"]:
        clean_question(question, primary_ids)

    by_category: dict[str, list[dict[str, Any]]] = {}
    for question in data["questions"]:
        by_category.setdefault(question["category"], []).append(question)

    theory = []
    for node in data["taxonomy"]:
        note = build_theory_note(node, by_category.get(node["id"], []), PRIMARY_BY_CATEGORY.get(node["id"], set()))
        if note is not None:
            theory.append(note)

    ordered = {
        "meta": data["meta"],
        "config": data["config"],
        "taxonomy": data["taxonomy"],
        "theory": theory,
        "questions": data["questions"],
    }
    TECWEB.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Updated {TECWEB}")
    print(f"Theory notes: {len(theory)}")
    print(f"Primary questions: {sum(1 for q in ordered['questions'] if q.get('primary') is True)}")


if __name__ == "__main__":
    main()
