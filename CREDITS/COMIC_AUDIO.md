# Новые комические реплики, v1.3.0

`art/voice/fish/*.ogg`: восемь русских реплик, синтезированных локально Chatterbox Multilingual
(`chatterbox-tts 0.1.7`, встроенный голос модели; реальные люди и образцы их голосов не использовались).
Система маркировки Perth включена штатным генератором. Тексты и файлы перечислены в `art/voice/fish/manifest.json`.

Модель: https://huggingface.co/ResembleAI/chatterbox
Исходный проект: https://github.com/resemble-ai/chatterbox
Генератор: `tools/gen_fun_voices.py`. Для воспроизведения использованы Python 3.11, CPU,
torch/torchaudio 2.6.0, soundfile, chatterbox-tts 0.1.7 и setuptools 80.10.2 (для pkg_resources в Perth).
Формат: mono OGG Vorbis, частота модели. Во время игры Torch и Chatterbox не нужны.

`art/sfx/goose.wav` — собственный короткий синтезированный гогот (волновая форма, без чужой записи).
