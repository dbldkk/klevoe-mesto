#!/usr/bin/env python3
"""Generate SpeechBank voice lines with Chatterbox Multilingual (CPU-friendly, resumable).

Uses the model's built-in voice only (no audio_prompt_path, no cloning of real people).
NPCs get distinct voices via exaggeration / cfg / temperature and a mild pitch shift.
Output: art/voice/<speaker>/<sha1[:16]>.ogg  — mono Vorbis ~72 kbps.
The hash matches Sfx.voice_key() in scripts/autoload/sfx.gd (clean + SHA1).

Resume: existing OGGs larger than 2 KB are skipped. Index and coverage are rewritten
after each successful line.

Usage:
  /workspace/tools/chatterbox-venv/bin/python -u tools/gen_voices.py
  VOICE_LIMIT=20  — stop after N new files
  VOICE_PRIORITY_ONLY=1 — only the first-pass priority set
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "scripts" / "world" / "npc" / "speech_bank.gd"
OUT = ROOT / "art" / "voice"
LOG = Path(os.environ.get("VOICE_LOG", "/tmp/voice-work/gen_voices.log"))
MANIFEST = OUT / "index.json"
COVERAGE = OUT / "coverage.json"

# Built-in voice only. Pitch is sox cents/100 (semitones).
VOICES = {
    "zoya": {"exag": 0.55, "cfg": 0.45, "temp": 0.7, "pitch": 1.5},
    "zina": {"exag": 0.5, "cfg": 0.5, "temp": 0.75, "pitch": 2.0},
    "valya": {"exag": 0.45, "cfg": 0.55, "temp": 0.7, "pitch": 1.0},
    "nina": {"exag": 0.58, "cfg": 0.4, "temp": 0.75, "pitch": 2.5},
    "tolya": {"exag": 0.45, "cfg": 0.5, "temp": 0.65, "pitch": -1.5},
    "petrovich": {"exag": 0.4, "cfg": 0.55, "temp": 0.6, "pitch": -3.5},
    "semenov": {"exag": 0.5, "cfg": 0.5, "temp": 0.65, "pitch": -1.0},
    "semenych": {"exag": 0.42, "cfg": 0.6, "temp": 0.6, "pitch": -2.5},
    "mikhalych": {"exag": 0.48, "cfg": 0.55, "temp": 0.65, "pitch": -2.0},
    "gena": {"exag": 0.55, "cfg": 0.45, "temp": 0.75, "pitch": -0.5},
    "thimble": {"exag": 0.7, "cfg": 0.35, "temp": 0.8, "pitch": 0.5},
    "dealer": {"exag": 0.5, "cfg": 0.5, "temp": 0.7, "pitch": 0.8},
    "bouncer": {"exag": 0.52, "cfg": 0.5, "temp": 0.65, "pitch": -2.8},
    "alina": {"exag": 0.58, "cfg": 0.45, "temp": 0.72, "pitch": 3.6},
    "katya": {"exag": 0.62, "cfg": 0.42, "temp": 0.75, "pitch": 2.4},
    "nika": {"exag": 0.55, "cfg": 0.48, "temp": 0.7, "pitch": 4.2},
}

# Greetings / trade / police / Zoya / Tolya / bouncer first, then the rest.
PRIORITY = [
    "zoya", "tolya", "zina", "mikhalych",
    "petrovich", "semenov", "nina", "bouncer",
    "semenych", "valya", "gena", "thimble", "dealer",
]
# In the first pass, take all lines of priority speakers (they're short banks).
# Second pass is anything else (none today).


def log(msg: str) -> None:
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def clean(text: str) -> str:
    """Must match Sfx._clean() in sfx.gd."""
    t = text
    i = t.find(": «")
    if 0 < i < 30:
        t = t[i + 3 :]
    for ch in ["«", "»", "\n", "*"]:
        t = t.replace(ch, " ")
    out = []
    for ch in t:
        c = ord(ch)
        if c < 0x2000 or (0x0400 <= c <= 0x04FF):
            out.append(ch)
    return "".join(out).strip()


def voice_id(text: str) -> str:
    """Must match Sfx.voice_key() / _voice_hash(_clean(text))."""
    t = clean(text)
    return hashlib.sha1(t.encode("utf-8")).hexdigest()[:16]


def extract_jobs() -> list[dict]:
    src = BANK.read_text(encoding="utf-8")
    jobs = []
    seen = set()
    current = None
    # function name at column 0: static func zoya / zoya_ctx / bouncer …
    for m in re.finditer(
        r"static func ([a-z_]+)\(\)[\s\S]*?(?=\nstatic func |\Z)", src
    ):
        name = m.group(1)
        if name in ("ctx", "_has_fish", "_pick_ctx"):
            continue
        speaker = name
        if speaker.endswith("_ctx"):
            speaker = speaker[: -len("_ctx")]
        elif speaker.endswith("_jail"):
            speaker = speaker[: -len("_jail")]
        elif speaker.endswith("_money"):
            speaker = speaker[: -len("_money")]
        body = m.group(0)
        for quoted in re.findall(r'"([^"]*)"', body):
            # skip context rule keys like "drunk", "rain"
            if quoted in ("", "drunk", "stinky", "wet", "rain", "morning",
                          "evening", "night", "fish", "hour", "day", "money", "jailed"):
                continue
            if len(quoted) < 8:
                continue
            vid = voice_id(quoted)
            key = (speaker, vid)
            if key in seen:
                continue
            seen.add(key)
            jobs.append({
                "speaker": speaker,
                "text": quoted,
                "clean": clean(quoted),
                "id": vid,
            })
    return jobs


def order_jobs(jobs: list[dict]) -> list[dict]:
    def key(j):
        sp = j["speaker"]
        pri = PRIORITY.index(sp) if sp in PRIORITY else 99
        return (pri, j["text"])
    return sorted(jobs, key=key)


def dest_for(job: dict) -> Path:
    return OUT / job["speaker"] / f"{job['id']}.ogg"


def is_done(job: dict) -> bool:
    p = dest_for(job)
    return p.exists() and p.stat().st_size > 2000


def write_index(jobs: list[dict]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    idx = []
    by = defaultdict(lambda: {"done": 0, "total": 0, "missing": []})
    for j in jobs:
        by[j["speaker"]]["total"] += 1
        d = dest_for(j)
        if is_done(j):
            by[j["speaker"]]["done"] += 1
            idx.append({
                "speaker": j["speaker"],
                "id": j["id"],
                "text": j["text"],
                "bytes": d.stat().st_size,
            })
        else:
            by[j["speaker"]]["missing"].append(j["text"][:80])
    MANIFEST.write_text(json.dumps(idx, ensure_ascii=False, indent=2), encoding="utf-8")
    cov = {
        "done": sum(v["done"] for v in by.values()),
        "total": sum(v["total"] for v in by.values()),
        "by_speaker": {k: {"done": v["done"], "total": v["total"]} for k, v in sorted(by.items())},
    }
    COVERAGE.write_text(json.dumps(cov, ensure_ascii=False, indent=2), encoding="utf-8")


def to_ogg(wav_path: Path, ogg_path: Path, pitch: float) -> None:
    pitched = wav_path.with_suffix(".pit.wav")
    cents = int(round(pitch * 100))
    src = wav_path
    if cents != 0:
        rc = os.system(f'sox "{wav_path}" "{pitched}" pitch {cents} 2>/dev/null')
        if rc == 0 and pitched.exists() and pitched.stat().st_size > 100:
            src = pitched
    os.system(
        f'ffmpeg -y -loglevel error -i "{src}" -ac 1 -ar 24000 -c:a libvorbis -b:a 72k "{ogg_path}"'
    )
    for p in (pitched, wav_path):
        if p.exists():
            p.unlink()


def main() -> int:
    limit = int(os.environ.get("VOICE_LIMIT", "0") or "0")
    jobs = order_jobs(extract_jobs())
    if os.environ.get("VOICE_PRIORITY_ONLY") == "1":
        jobs = [j for j in jobs if j["speaker"] in PRIORITY]
    write_index(jobs)
    pending = [j for j in jobs if not is_done(j)]
    if limit > 0:
        pending = pending[:limit]
    log(f"jobs {len(jobs)} pending {len(pending)} already {sum(1 for j in jobs if is_done(j))}")
    if not pending:
        log("nothing to generate")
        return 0

    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    import torch
    import torchaudio
    import numpy as np

    log("loading ChatterboxMultilingualTTS (CPU)…")
    t0 = time.time()
    model = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
    sr = getattr(model, "sr", 24000)
    log(f"model ready in {time.time() - t0:.1f}s, sr={sr}")

    times: list[float] = []
    ok = 0
    work = Path("/tmp/voice-work")
    work.mkdir(parents=True, exist_ok=True)
    for i, j in enumerate(pending, 1):
        dest = dest_for(j)
        dest.parent.mkdir(parents=True, exist_ok=True)
        wav_path = work / f"{j['speaker']}_{j['id']}.wav"
        cfg = VOICES.get(j["speaker"], {"exag": 0.5, "cfg": 0.5, "temp": 0.7, "pitch": 0.0})
        text = j["clean"] or j["text"]
        log(f"[{i}/{len(pending)}] {j['speaker']} {text[:70]}")
        t1 = time.time()
        try:
            wav = model.generate(
                text,
                language_id="ru",
                exaggeration=cfg["exag"],
                cfg_weight=cfg["cfg"],
                temperature=cfg["temp"],
            )
            if isinstance(wav, tuple):
                wav = wav[0]
            if not isinstance(wav, torch.Tensor):
                wav = torch.tensor(np.asarray(wav))
            if wav.ndim == 1:
                wav = wav.unsqueeze(0)
            torchaudio.save(str(wav_path), wav.cpu(), sr)
            to_ogg(wav_path, dest, cfg["pitch"])
            elapsed = time.time() - t1
            times.append(elapsed)
            if dest.exists() and dest.stat().st_size > 1000:
                ok += 1
                avg = sum(times) / len(times)
                left = (len(pending) - i) * avg
                log(f"  ok {dest.stat().st_size}b in {elapsed:.1f}s  avg {avg:.1f}s  ETA {left/60:.1f}m")
            else:
                log(f"  FAIL empty ogg after {elapsed:.1f}s")
        except Exception as e:
            log(f"  ERROR {type(e).__name__}: {e}")
        write_index(jobs)
    write_index(jobs)
    log(f"done generated={ok}/{len(pending)}")
    return 0 if ok or not pending else 1


if __name__ == "__main__":
    raise SystemExit(main())
