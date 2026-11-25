extends Node
## Звуки. Sfx.play("splash", позиция) — 3D-звук в мире (или 2D, если позиции нет).
## Sfx.loop("reel", вкл/выкл) — зацикленный 2D-звук. Фон (птицы, сверчки, вода, музыка казино) — сам.
## Файлы — art/sfx/*.{ogg,wav}. Сначала ищем .ogg (CC0), потом .wav. Варианты name0..name2 — случайный.
## club_music и wedding_music — тот же файл, что casino_music (чтобы не плодить копии).
## Голос NPC: art/voice/<speaker>/<hash>.ogg, иначе системный TTS, иначе бормотание.

const DIR := "res://art/sfx/"
const LOOPS := ["tv", "reel", "pee", "rain", "engine", "bubbling", "oars", "bike", "amb_day", "amb_night", "amb_water", "casino_music",
	"wedding_music", "funeral_music", "club_music", "wind"]
const ALIASES := {"club_music": "casino_music", "wedding_music": "casino_music"}
const VOICE_DIR := "res://art/voice/"
## Шины громкости (v0.8): регулируются в настройках отдельно.
const BUSES := ["Effects", "Ambient", "Music", "Voices"]

var volume_db := 0.0
var _cache: Dictionary = {}
var _loops: Dictionary = {}
var _amb: Dictionary = {}
var _amb_t := 0.0


var _babble_t: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for n in ["amb_day", "amb_night", "amb_water", "casino_music"]:
		var p := AudioStreamPlayer.new()
		p.stream = stream_of(n)
		p.volume_db = -80.0
		p.bus = "Music" if n == "casino_music" else "Ambient"
		add_child(p)
		_amb[n] = p


func _make_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


## На какую шину ставить звук: "sfx" / "amb" / "music" / "voice".
static func bus_for(kind: String) -> String:
	match kind:
		"amb": return "Ambient"
		"music": return "Music"
		"voice": return "Voices"
	return "Effects"


## Громкость шины 0..1.
func set_bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


# ------------------------------------------------------------ речь NPC

## Голосовой движок системы (на Windows — SAPI, русские голоса Ирина/Павел…). Пусто — нет русского голоса.
var _tts_male := ""
var _tts_female := ""
var _tts_checked := false
const SAY_DIST := 22.0


func has_tts() -> bool:
	_check_tts()
	return _tts_female != "" or _tts_male != ""


func _check_tts() -> void:
	if _tts_checked:
		return
	_tts_checked = true
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false) or DisplayServer.get_name() == "headless":
		return
	for v in DisplayServer.tts_get_voices():
		var lang := String(v.get("language", ""))
		if not lang.begins_with("ru"):
			continue
		var nm := String(v.get("name", "")).to_lower()
		var id := String(v.get("id", ""))
		if nm.contains("pavel") or nm.contains("dmitr") or nm.contains("male") and not nm.contains("female") or nm.contains("павел") or nm.contains("дмитр"):
			if _tts_male == "":
				_tts_male = id
		elif _tts_female == "":
			_tts_female = id
	if _tts_female == "":
		_tts_female = _tts_male
	if _tts_male == "":
		_tts_male = _tts_female


## NPC говорит фразу: понятной речью (если в системе есть русский голос и в настройках «Речь»),
## иначе «симлишем». voice: m, m_low, f, old. pos — откуда (дальше SAY_DIST — не слышно).
func voice_key(text: String) -> String:
	return _voice_hash(_clean(text))


func _voice_hash(t: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(t.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


## Готовая реплика (Chatterbox) или null, если файла нет — тогда TTS / бормотание.
func voice_stream(speaker: String, text: String) -> AudioStream:
	var key := _voice_hash(_clean(text))
	var folders: Array[String] = []
	if speaker != "":
		folders.append(speaker)
	folders.append("_")
	for folder in folders:
		var path := VOICE_DIR + folder + "/" + key + ".ogg"
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _play_voice(stream: AudioStream, pos: Vector3, dist: float) -> void:
	if stream == null or not is_inside_tree():
		return
	var vol := Settings.vol.get("Voices", 0.9) as float
	vol *= Saves.volume * (1.0 - clampf(dist / SAY_DIST, 0.0, 1.0) * 0.6)
	var db := linear_to_db(maxf(vol, 0.0001)) - 2.0
	if pos != Vector3.ZERO:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = db
		p3.bus = "Voices"
		p3.unit_size = 7.0
		p3.max_distance = SAY_DIST + 6.0
		get_tree().root.add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = db
		p2.bus = "Voices"
		add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)


func say(pos: Vector3, voice: String, text: String, speaker := "") -> void:
	var cam := get_viewport().get_camera_3d()
	var dist := 0.0
	if cam and pos != Vector3.ZERO:
		dist = cam.global_position.distance_to(pos)
		if dist > SAY_DIST:
			return
	var mode: int = Settings.voice_mode
	if mode == 2:
		return
	var recorded := voice_stream(speaker, text)
	if recorded:
		_play_voice(recorded, pos, dist)
		return
	if mode == 0 and has_tts():
		var clean := _clean(text)
		if clean.length() < 2:
			return
		var female := voice == "f" or voice == "old"
		var id := _tts_female if female else _tts_male
		var pitch := {"m": 0.95, "m_low": 0.75, "f": 1.1, "old": 1.35}.get(voice, 1.0) as float
		if female and id == _tts_male:
			pitch += 0.35   # голос только мужской — поднимем
		elif not female and id == _tts_female:
			pitch -= 0.4    # голос только женский — опустим
		var vol := Settings.vol.get("Voices", 0.9) as float
		vol *= Saves.volume * (1.0 - clampf(dist / SAY_DIST, 0.0, 1.0) * 0.6)
		DisplayServer.tts_speak(clean, id, clampi(int(vol * 100.0), 0, 100), clampf(pitch, 0.3, 2.0), 1.05 if voice != "old" else 0.95, 0, true)
		return
	babble(pos, voice, text.length())


static func _clean(t: String) -> String:
	var i := t.find(": «")
	if i > 0 and i < 30:
		t = t.substr(i + 3)
	for ch in ["«", "»", "\n", "*"]:
		t = t.replace(ch, " ")
	t = t.replace("\n", " ")
	var out := ""
	for k in t.length():
		var c := t.unicode_at(k)
		if c < 0x2000 or (c >= 0x0400 and c <= 0x04FF):
			out += t[k]
	return out.strip_edges()


## «Симлиш» — бормотание NPC вместо озвучки. voice: m, m_low, f, old.
func babble(pos: Vector3, voice: String, text_len: int = 20) -> void:
	var key := "%s:%d:%d" % [voice, int(pos.x), int(pos.z)]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_babble_t.get(key, -9.0)) < 0.8:
		return
	_babble_t[key] = now
	var name := "babble_" + voice
	play(name, pos, -6.0, 0.12, "Voices")
	if text_len > 38:
		get_tree().create_timer(0.9).timeout.connect(func() -> void: play(name, pos, -7.0, 0.12, "Voices"))


func stream_of(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var key := String(ALIASES.get(name, name))
	var s: AudioStream = null
	var exts: Array[String] = [".ogg", ".wav"]
	for ext in exts:
		var path := DIR + key + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	if s == null:
		for ext in exts:
			if ResourceLoader.exists(DIR + key + "0" + ext):
				_cache[name] = null   # варианты — выбираются в play
				return null
	s = _make_loop(s, name)
	_cache[name] = s
	return s


func _make_loop(s: AudioStream, name: String) -> AudioStream:
	if s == null:
		return s
	var looped := name in LOOPS or String(ALIASES.get(name, "")) in LOOPS
	if not looped:
		return s
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	if s is AudioStreamOggVorbis:
		var o := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		o.loop = true
		return o
	return s


func _pick(name: String) -> AudioStream:
	var s := stream_of(name)
	if s:
		return s
	var v := stream_of("%s%d" % [name, randi() % 3])
	return v


## Разовый звук. pos — где в мире (null — прямо «в ушах»).
func play(name: String, pos: Variant = null, db := 0.0, pitch_var := 0.08, bus := "Effects") -> void:
	var s := _pick(name)
	if s == null or not is_inside_tree():
		return
	var pitch := randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	if pos is Vector3:
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.volume_db = db + volume_db
		p.pitch_scale = pitch
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.bus = bus
		get_tree().root.add_child(p)
		p.global_position = pos
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = db + volume_db
		p.pitch_scale = pitch
		p.bus = bus
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


## Зацикленный звук (катушка, струя).
func loop(name: String, on: bool, db := -4.0) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if on:
		if p == null:
			p = AudioStreamPlayer.new()
			p.stream = stream_of(name)
			p.bus = "Music" if name.ends_with("_music") else "Effects"
			add_child(p)
			_loops[name] = p
		p.volume_db = db + volume_db
		if not p.playing:
			p.play()
	elif p and p.playing:
		p.stop()


func _process(delta: float) -> void:
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	_amb_t = 0.25
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	var dc := get_tree().get_first_node_in_group("day_cycle")
	var target := {"amb_day": -80.0, "amb_night": -80.0, "amb_water": -80.0, "casino_music": -80.0}
	if me:
		var p := me.global_position
		var night: bool = dc != null and dc.is_night()
		var indoor := _inside_any(p)
		target["amb_night" if night else "amb_day"] = -18.0 if indoor else -9.0
		var ld := Terrain.lake_distance(p.x, p.z).x
		target.amb_water = lerpf(-8.0, -40.0, clampf(ld / 14.0, 0.0, 1.0)) if ld < 14.0 else -80.0
		var music_db := -80.0
		for node_name in ["World/Casino", "World/StripClub"]:
			var venue := get_tree().root.get_node_or_null(node_name) as Node3D
			if venue == null:
				continue
			var l := venue.to_local(p)
			var inside := absf(l.x) < 10.0 and absf(l.z) < 8.0 and l.y < 5.0
			var d := venue.global_position.distance_to(p)
			var db := -10.0 if inside else (lerpf(-24.0, -60.0, clampf((d - 8.0) / 25.0, 0.0, 1.0)) if d < 33.0 else -80.0)
			music_db = maxf(music_db, db)
		target.casino_music = music_db
	for n in _amb:
		var pl: AudioStreamPlayer = _amb[n]
		var want: float = target[n] + volume_db
		if want <= -70.0:
			pl.volume_db = move_toward(pl.volume_db, -80.0, 6.0)
			if pl.playing and pl.volume_db <= -79.0:
				pl.stop()
		else:
			if not pl.playing:
				pl.volume_db = -60.0
				pl.play()
			pl.volume_db = move_toward(pl.volume_db, want, 3.0)


func _inside_any(p: Vector3) -> bool:
	for n in ["World/House", "World/LiquorStore", "World/Casino", "World/Shop", "World/Club", "World/StripClub"]:
		var b := get_tree().root.get_node_or_null(n) as Node3D
		if b:
			var l := b.to_local(p)
			if absf(l.x) < 8.0 and absf(l.z) < 6.0 and l.y < 4.0:
				if b.name != "House" or (absf(l.x) < 4.5 and absf(l.z) < 3.5):
					return true
	return false
