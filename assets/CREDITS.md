# Ассеты и лицензии

## Персонажи — Jampa Beat'em up Guys
- Источник: https://opengameart.org/content/jampa-beatem-up-guys
- Лицензия: **CC0** (public domain) — можно использовать в коммерческой игре без указания автора.
- Два листа: `beatemupGuy1.png` (герой, жёлтые шорты, зелёная кепка, с битой) и `beatemupGuy2.png` (враг, зелёные шорты).
- Кадры нарезаны скриптом `detect.cjs` (обход связных областей по листу) и сохранены в `assets/jampa/guy1/` и `assets/jampa/guy2/`: 9 кадров ходьбы, idle, прыжок, падение, удар в прыжке, 2 кадра punch1, 3 кадра punch2.
- В игре: `scripts/fighter.gd` собирает `SpriteFrames` из этих PNG; анимации idle/walk/punch1/punch2/hurt/down.

## Прочее
- Улица, дома, фонари, разметка — рисуются кодом в `scripts/main.gd`.
- Вспышка удара — `scripts/hit_fx.gd` (код).
- Промежуточные превью кандидатов лежат в `assets/_candidates/` (не используются в игре).
