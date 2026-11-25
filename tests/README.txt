Проверки Godot 4.7.2

Сначала импортируйте проект: Godot --headless --editor --path <project> --import --quit

Для тестов создайте в корне проекта временный override.cfg:
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="Codex/game-fish-qa-20261125"

Это отдельная папка данных. Обычные сохранения игрока не используются.
После тестов уберите override.cfg перед обычной игрой или экспортом!

Автопроверки (из v1.1 плюс голоса NPC, площадки на суше, танцовщицы «Неона»):
Godot --headless --path <project> res://tests/regression.tscn

Кооператив: запустите хост и после HOST_READY клиент в другом процессе.
Godot --headless --path <project> res://tests/coop.tscn -- --qa-host --profile=6
Godot --headless --path <project> res://tests/coop.tscn -- --profile=7

Графическая проверка и две картинки в тестовой папке данных:
Godot --path <project> res://tests/visual.tscn -- --profile=5

Успешные итоги: RESULT: все проверки passed, 0 failed; COOP_RESULT: PASS в обеих копиях;
VISUAL_RESULT: PASS. Логи не должны содержать SCRIPT ERROR / ERROR / FAIL.
Тесты и override.cfg исключены из экспорта игры.

Дополнительно v1.3.0:
Godot --headless --path <project> res://tests/mischief.tscn
Godot --path <project> res://tests/visual_mischief.tscn
Godot --path <project> res://tests/performance.tscn

Regression: 136 проверок; Mischief: 64 проверки (включая 12 боёв с царём-сомом).
Кооператив дополнительно проверяет больницу, гуся, позднюю синхронизацию пятна и сохранение слепоты.
В benchmark фиксируются вид, 1280x720, качество 2, трава 1, выключен VSync; сравнивать на одном компьютере.
При оценке стартовых кадров не использовать TIME_PROCESS: счётчик обновляется с задержкой после загрузки.
