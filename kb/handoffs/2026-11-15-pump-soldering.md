---
title: "Handoff: Pump soldering 2026-11-15"
type: handoff
status: in-progress
branch: codex/pump-soldering
date: 2026-11-15
---

# Handoff: Pump soldering 2026-11-15

Паяльна станція тепер окрема й багаторазова. Водяний насос ламається випадково.

## Done
- `SolderStation` (server): 3D-верстак у Енергоблоці (стіл, бездротовий паяльник у зарядній підставці, плата в тримачі, лампа, губка, табличка). Стоїть на `Workspace.MB_Interactables.MB_SolderStation` (якоріна деталь), або на `SolderConfig.StationCFrame`. API: `giveBoard`, `takeBoard`, `carrying`, `onLost`, `reset`. Нові плати додаються в `SolderConfig.Boards`.
- `WaterPump` (server): насос працює від старту місії і ламається після випадкових `PumpBreakMin..Max` секунд роботи. Флоу: вимкнути живлення (Q / клік), F — дістати плату, віднести на станцію, спаяти, F — вставити, увімкнути живлення. Іскри, червоне світло й табличка над насосом, тости всім гравцям. Атрибут `PumpWorking` перевіряє `MB_ResourceServer` перед видачею води.
- `SolderClient`: картка «Як паяти» з 3 кроків, термометр із зонами (холодне / плавиться / загаряче), «ВІДПУСКАЙ!», дим, зірка за швидке відпускання, оцінка ★★★, тест плати з LED. Контакти в нових місцях щоразу. Миша, дотик, Пробіл / ButtonA. Підказка, що робити з платою.
- Видалено `PumpRepair.server/client`. Тексти en + uk (`solder.*`, `pump.*`).
- Перевірено в Play-сесії (без збереження плейсу): станція й насос стартують без помилок, станція не перетинається з іншими деталями. UI міні-гри пройдено повністю: картка «Як паяти», нагрів і дим, «Загаряче» з повтором, 4 контакти, тест плати з LED, оцінка зірками. Після цього прямі доріжки до чипа (без перетинів), зірки ★ у прогресі за швидке відпускання.
- `selene src`, `stylua --check src`, `rojo build`, `lune run tests/solder-joint.luau` — усе чисто (тулчейн встановлено через rokit).

## Next
1. Змерджити PR, потім `git pull` і `rojo serve` (разом із `events/director`, щоб не стерти `EventDirector`). Видалити старі `Server.PumpRepair` і `Client.PumpRepair` у плейсі.
2. Team Test на двох гравцях; дотик і геймпад фізично.
3. `MB_ResourceServer` містить зміни для EventDirector (шторми лише через `MB_EventCommand`): без гілки `events/director` сонячних штормів не буде.

## Relations
- part_of [[Co-op campaign concept]]
- see_also [[Drill crafting]]
