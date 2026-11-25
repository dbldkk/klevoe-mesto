Проверки Godot 4.7.2

Сначала импортируйте проект: Godot --headless --editor --path <project> --import --quit

Для тестов создайте в корне проекта временный override.cfg:
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="Codex/game-fish-qa-20261125"

Это отдельная папка данных. Обычные сохранения игрока не используются.
После тестов уберите override.cfg перед обычной игрой или экспортом!

Автопроверки (31 из v0.8.3 плюс проверки удочки, таблички и камеры):
Godot --headless --path <project> res://tests/regression.tscn

Кооператив: запустите хост и после HOST_READY клиент в другом процессе.
Godot --headless --path <project> res://tests/coop.tscn -- --qa-host --profile=6
Godot --headless --path <project> res://tests/coop.tscn -- --profile=7

Графическая проверка и две картинки в тестовой папке данных:
Godot --path <project> res://tests/visual.tscn -- --profile=5

Успешные итоги: RESULT: все проверки passed, 0 failed; COOP_RESULT: PASS в обеих копиях;
VISUAL_RESULT: PASS. Логи не должны содержать SCRIPT ERROR / ERROR / FAIL.
Тесты и override.cfg исключены из экспорта игры.
