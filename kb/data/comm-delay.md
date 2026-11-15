---
title: Mars-Earth signal delay
type: data
tags:
- mars
- communication
- sparky
---

# Mars-Earth signal delay

Скільки летить радіосигнал між Марсом і Землею. Використовується в чаті зі Спаркі ([[Handoff: Sparky AI questions 2026-11-15 15:30]]).
How long a radio signal takes between Mars and Earth. Used by Sparky's chat with Earth.

## Observations
- [fact] NASA Goddard, «Space Communications: 7 Things You Need to Know»: «At Mars' closest approach — about 35 million miles away — the delay is about four minutes.» і «When the planets are at their greatest distance — about 250 million miles away — the delay is around 24 minutes.» Джерело: https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/ (перевірено 2026-11-15).
- [decision] У грі сигнал летить `Config.CommDelayMinutes = 20` ігрових хвилин в один бік. Це ігрове значення в межах реальних 4–24 хв, яке обрав Yaroslav. Туди й назад виходить 40 ігрових хвилин, тобто 10 реальних секунд при `SolSeconds = 360`.
- [fact] Діапазон «3–22 хв» з інших сайтів рахує інші відстані. У грі беремо цифри NASA (4–24).

## Relations
- part_of [[NASA data sources]]
