# Zombie Beat (slice)

Аркадный битэм-ап на Godot 4.7.2: ночная улица, герой против зомби, три волны. Враги подходят с четырёх сторон, бьют по очереди, тела не слипаются.

Играть: https://kirtus228.github.io/zombie-beat/

## Управление

- `WASD` / стрелки — ходьба по улице (влево-вправо и по глубине)
- `Shift` — бег (на удержание)
- **левая кнопка мыши / `Space` / `J`** — удар
- `K` (или `X`) — прыжок; в прыжке удар с разворота (кадр jumpkick)
- `M` — звук вкл/выкл
- `R` — рестарт

Раскладка как в битэмапах (Streets of Rage 4, Shredder's Revenge): движение на WASD,
удар на лицевую кнопку (у нас — ЛКМ/Space), прыжок и бег отдельно.

## Что внутри

- `scenes/`, `scripts/` — сцены и GDScript
- `assets/` — спрайты и анимации (пак, нарезанный по кадрам)
- `tools/` — служебные GDScript-проверки кадров и выравнивания
- `docs/` — собранная веб-версия, отдаётся через GitHub Pages (ветка `main`, папка `/docs`)
- `PLAN.md` — план слайса и результат

## Сборка web

```
node tools/godot-dev/godot-dev.mjs check games/zombie-beat
node tools/godot-dev/godot-dev.mjs export Web games/zombie-beat/build/web/index.html games/zombie-beat
```

Дальше скопировать `build/web/*` в `docs/`.

Требуется Godot 4.7.2 с шаблонами экспорта (установлены в `%APPDATA%\Godot\export_templates\4.7.2.stable`).