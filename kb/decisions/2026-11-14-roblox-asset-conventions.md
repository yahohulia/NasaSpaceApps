---
title: 'Decision: Roblox asset conventions'
type: decision
status: proposed
tags:
- engine
- assets
- roblox
date: 2026-11-14
permalink: sol-sandbox/decisions/2026-11-14-roblox-asset-conventions
---

# Decision: Roblox asset conventions

Правила для моделей, зображень, звуків та UI в Roblox. Вони замінюють частину про ассети з [[Decision: content and asset conventions]] (палітра, PNG-спрайти й скіл `design-handoff` більше не діють). Статус — proposed: команда має погодити.

## Observations
- [decision] Де що лежить. 3D-світ, моделі й макети UI роблять руками в плейсі Studio (Team Create). Вони не потрапляють у git. Код і дані лежать у `src/` і синхронізуються через Rojo.
- [decision] ID ассетів код бере лише з одного реєстру — `src/shared/Assets.luau`. Кожен запис містить `id`, `kind`, `credit` і `source`. Сирі `rbxassetid://` в інших скриптах не пишемо.
- [decision] Хто завантажує. Звук, відео й анімації завантажує власник гри (акаунт Ярослава). Тоді грі не треба окремо давати дозвіл. Якщо ассет завантажив колаборант, він одразу дає дозвіл грі, як описано в [[Decision: Roblox engine]].
- [decision] Безкоштовні моделі з Creator Store. Перед вставкою перевіряємо, чи нема в моделі скриптів (`Script`, `LocalScript`, `ModuleScript`). Незнайомі скрипти видаляємо, бо в безкоштовних моделях бувають бекдори. Автора моделі записуємо в `credit`.
- [decision] Зображення NASA можна брати з підписом. Підпис іде в `credit` і показується в грі (екран «Автори»). Логотип NASA («meatball») не використовуємо ніде, і на Спаркі теж.
- [decision] Аудиторія 7–12 років. Без страшних звуків, скримерів і різких спалахів. Тривога (пилова буря, сонячний спалах) звучить спокійно і не лякає.
- [decision] Назви інстансів у PascalCase. Модулі бази лежать у `Workspace/Base/<Module>` (наприклад `Workspace/Base/Greenhouse`). Камери для оператора — частини з назвою `Cam_<Module>` у `Workspace/Cameras`.
- [fact] Перевірено 2026-11-14 (https://create.roblox.com/docs/projects/assets/privacy.md, https://create.roblox.com/docs/audio/assets.md). Зображення, декалі й меші колаборанта за замовчуванням Open Use, тож у грі їх видно. Виняток — якщо автор увімкнув «restrict assets on creation». Аудіо після завантаження **приватне**: ним спочатку може користуватися лише автор. Без дозволу для гри (universe) звук у грі не грає, а в Output з'являється помилка, на яку можна клікнути. Якщо вставити Restricted-ассет у чужу гру, дозвіл автоматично отримує і власник гри. Ассети з Creator Store — Open Use, з ними проблем нема.
- [risk] Зображення й аудіо проходять модерацію Roblox, а вона може тривати довго. Завантажуємо заздалегідь, а не в останній день.
- [question] Чи потрібні колаборантам ассети, які завантажив власник (пакети, моделі)? На сторінці про колаборацію про це не сказано. Перевірити на практиці.
- [decision] Небо (2026-11-14). `Lighting.Sky` має чорні грані скайбоксу (вбудована текстура `rbxasset://textures/blackBkg_square.png`) і `StarCount` = 5000. Колір неба малює `Atmosphere`, а змінює його клієнтський `src/client/SkyClient.luau` за висотою Сонця: день (карамельне небо) → захід (блакитне сяйво біля Сонця, як на знімках марсоходів) → ніч (чорне небо із зорями). Пресети лежать у `DataMapping.sky`. Події погоди накладаються зверху. У Studio атрибут `Lighting@DebugClockTime` (0–24) показує небо в будь-яку годину. Старі текстури збережені в атрибутах `PreMars_*` на `Sky`.

## Relations
- supersedes [[Decision: content and asset conventions]]
- depends_on [[Decision: Roblox engine]]
- part_of [[Index]]
- see_also [[NASA data sources]]