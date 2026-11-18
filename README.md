# Zombie Beat (slice)

Аркадный битэм-ап на Godot 4.7.2: ночная улица, герой против зомби, три волны. Враги подходят с четырёх сторон, бьют по очереди, тела не слипаются.

Играть: https://kirtus228.github.io/zombie-beat/

## Управление

- `WASD` / стрелки — ходьба по улице (влево-вправо и по глубине)
- `J` — удар
- `R` — рестарт

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
