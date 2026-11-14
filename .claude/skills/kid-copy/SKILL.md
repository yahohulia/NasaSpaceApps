---
name: kid-copy
description: Write or review any player-facing text in the game for kids aged 7–12, in Ukrainian and English — CAPCOM messages, hints, tutorial, mission briefings and debriefs, science fact cards, button labels, failure screens. Use whenever you add or change UI text, i18n strings, mission texts or explanations of space science terms.
---

# Player-facing text for kids 7–12

## Voice
- CAPCOM is a friendly mission-control colleague: calm, encouraging, never scary, never sarcastic. "Ми", not "ти зробив помилку".
- Short sentences (≤ 12 words for in-game messages, ≤ 2 sentences per message). One idea per message.
- Concrete over abstract: "Кисень тікає через дірку в стіні" instead of "Розгерметизація модуля".
- Every message that reports a problem also hints what to do: "Батарея майже порожня. Вимкни науку до ранку."
- No death or injury. Failure = "Місію перервано, екіпаж повертається на Землю" + what to try next time.
- Praise effort and good decisions, not luck.

## Science terms
Explain a term in one short clause the first time it appears in a mission, then use it freely:
- сол → "марсіанська доба, трохи довша за земну"
- доза радіації → "скільки радіації отримав організм"
- сонячна вспишка / SEP → "вибух на Сонці, після якого летять швидкі частинки"
- реголіт → "пил і каміння на поверхні Місяця чи Марса"
Keep a glossary in `kb/data/glossary.md` (create it if missing) and reuse the same wording everywhere.

## Real data in text
- Say clearly what is real: "Це справжня вспишка, яку NASA зафіксувало 10 травня 2024 року."
- Say when the game simplifies: "У грі ніч коротша, щоб не чекати 14 днів."
- Numbers only if a kid can feel them: compare ("як 10 рентгенів у лікарні") rather than raw units — and the comparison must be sourced in `kb/data/` (see `nasa-data` skill).

## Strings, not hardcoded text
- All text goes through i18n keys; never hardcode player-facing strings in game code.
- Files: `src/i18n/uk.json` and `src/i18n/en.json` (same keys in both). Key style: `area.thing.state`, e.g. `capcom.leak.detected`, `mission.m04.brief.1`.
- Ukrainian is usually ~20–30% longer than English — check that UI elements fit the Ukrainian version.
- Use placeholders, not string concatenation: `"Екіпаж отримав +{dose} ☢️"`.

## Review checklist
- [ ] Both `uk` and `en` exist, same meaning, same keys
- [ ] Readable aloud by an 8-year-old without stumbling
- [ ] No unexplained jargon; terms match the glossary
- [ ] Problem messages contain a hint
- [ ] Real vs. simplified is stated honestly
- [ ] Fits the UI (check the Ukrainian length)
