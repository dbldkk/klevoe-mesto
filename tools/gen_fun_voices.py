from pathlib import Path
import hashlib
import json
import os
import random
import torch
import soundfile as sf
from chatterbox.mtl_tts import ChatterboxMultilingualTTS

root = Path(__file__).resolve().parents[1] / 'art/voice/fish'
root.mkdir(parents=True, exist_ok=True)
torch.set_num_threads(4)
random.seed(42)
torch.manual_seed(42)
lines = [
    'Не жарь меня! У меня ипотека и сорок мальков!',
    'Лох, я бы тебя съела!',
    'За Родину!',
    'Гражданин, это убийство свидетеля! Штраф триста пятьдесят рублей.',
    'Фу! Вы там совсем обалдели? В озере же рыба!',
    'Кря! Предъявите улов! Я русалка при исполнении!',
    'Ха-ха! Ведро тебе идёт! Почти депутат!',
    'Ай! Я не мешок картошки!',
]
print('Loading Chatterbox multilingual on CPU', flush=True)
model = ChatterboxMultilingualTTS.from_pretrained(device='cpu')
manifest = []
for text in lines:
    key = hashlib.sha1(text.encode('utf-8')).hexdigest()[:16]
    dest = root / (key + '.ogg')
    if not dest.exists():
        print('GENERATING: ' + text, flush=True)
        wav = model.generate(text, language_id='ru', exaggeration=0.65, cfg_weight=0.5, temperature=0.7)
        if isinstance(wav, tuple):
            wav = wav[0]
        audio = wav.detach().cpu().numpy().squeeze()
        sf.write(dest, audio, model.sr, format='OGG', subtype='VORBIS')
    manifest.append({'text':text,'file':dest.name,'speaker':'fish','engine':'Chatterbox Multilingual 0.1.7','reference':'built-in voice, no voice cloning'})
    print('SAVED: ' + dest.name, flush=True)
(root / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('VOICE_RESULT: PASS', flush=True)
