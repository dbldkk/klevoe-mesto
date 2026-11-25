extends Node
## Профиль игрока и сохранения миров (автозагрузка Saves).
##
## Профиль (user://profile.cfg) — постоянный id игрока на этом компьютере.
## Мир (user://worlds/<имя>.json) хранится у ХОСТА: состояние мира + данные всех
## игроков, которые в нём когда-либо играли (по их id).
## Если на одном компьютере запущено несколько копий игры, каждая берёт свой профиль.

## Перед записью мира — объекты мира кладут в Saves.world своё состояние.
signal before_save
## После загрузки мира хостом.
signal world_loaded

const WORLDS_DIR := "user://worlds/"
const SAVE_VERSION := 1

var profile_id: String = ""
var profile_name: String = "Рыбак"
var help_hidden: bool = false
var fullscreen: bool = true
var volume: float = 0.8
## Внешность: {shirt, pants, skin, hat, hat_color, face, stripes}
var skin: Dictionary = {}

var world_file: String = ""      ## имя файла без .json
var world: Dictionary = {}
var last_save_error := ""

var _slot := 0
var _lock_timer := 0.0
var _pid := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	_pid = OS.get_process_id()
	_pick_slot()
	_load_profile()


func _process(delta: float) -> void:
	_lock_timer -= delta
	if _lock_timer <= 0.0:
		_lock_timer = 2.0
		_write_lock()


# ------------------------------------------------------------ профиль

func _profile_path() -> String:
	return "user://profile.cfg" if _slot == 0 else "user://profile_%d.cfg" % _slot


func _lock_path(slot: int) -> String:
	return "user://profile_%d.lock" % slot


func _pick_slot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			_slot = arg.trim_prefix("--profile=").to_int()
			_write_lock()
			return
	# Несколько копий игры стартуют одновременно — разносим по времени.
	OS.delay_msec(randi_range(0, 400))
	for slot in 8:
		if _lock_is_free(slot):
			_slot = slot
			_write_lock()
			OS.delay_msec(60)
			if _read_lock(slot).get("pid", -1) == _pid:
				return
	_slot = 0


func _lock_is_free(slot: int) -> bool:
	var data := _read_lock(slot)
	if data.is_empty():
		return true
	return Time.get_unix_time_from_system() - float(data.get("t", 0.0)) > 6.0


func _read_lock(slot: int) -> Dictionary:
	var f := FileAccess.open(_lock_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_lock() -> void:
	var f := FileAccess.open(_lock_path(_slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"pid": _pid, "t": Time.get_unix_time_from_system()}))


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_profile_path())
	profile_id = cfg.get_value("profile", "id", "")
	profile_name = cfg.get_value("profile", "name", "Рыбак" if _slot == 0 else "Рыбак %d" % (_slot + 1))
	help_hidden = cfg.get_value("settings", "help_hidden", false)
	fullscreen = cfg.get_value("settings", "fullscreen", true)
	volume = cfg.get_value("settings", "volume", 0.8)
	apply_volume()
	skin = cfg.get_value("profile", "skin", {})
	if skin.is_empty():
		skin = {"shirt": randi() % 10, "pants": randi() % 6, "skin": randi() % 3, "hat": 1 + randi() % 3,
			"hat_color": randi() % 7, "face": randi() % 4, "stripes": false}
	if profile_id == "":
		profile_id = "%08x%08x" % [randi(), Time.get_ticks_usec() ^ _pid]
		save_profile()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "id", profile_id)
	cfg.set_value("profile", "name", profile_name)
	cfg.set_value("settings", "help_hidden", help_hidden)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("profile", "skin", skin)
	cfg.save(_profile_path())


# ------------------------------------------------------------ миры

func list_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(WORLDS_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json") and not file.ends_with(".json.bak"):
			continue
		var base := file.trim_suffix(".bak")
		if file.ends_with(".bak") and FileAccess.file_exists(WORLDS_DIR + base):
			continue
		var path := WORLDS_DIR + base
		var data := _read_world(path)
		if data.is_empty():
			continue
		out.append({
			"file": base.get_basename(),
			"name": data.get("name", base.get_basename()),
			"players": (data.get("players", {}) as Dictionary).size(),
			"modified": FileAccess.get_modified_time(path if FileAccess.file_exists(path) else path + ".bak"),
		})
	out.sort_custom(func(a, b): return a.modified > b.modified)
	return out


## Возвращает текст ошибки или "".
func create_world(display_name: String) -> String:
	display_name = display_name.strip_edges()
	if display_name == "":
		return "Введи название мира"
	var file := display_name.validate_filename().replace(" ", "_")
	if not _valid_world_file(file):
		return "Выбери другое название мира"
	if FileAccess.file_exists(WORLDS_DIR + file + ".json") or FileAccess.file_exists(WORLDS_DIR + file + ".json.bak"):
		return "Мир с таким названием уже есть"
	world_file = file
	world = {
		"version": SAVE_VERSION,
		"name": display_name,
		"created": Time.get_datetime_string_from_system(),
		"players": {},
	}
	if not save_world():
		close_world()
		return "Не удалось сохранить мир: " + last_save_error
	world_loaded.emit()
	return ""


func load_world(file: String) -> bool:
	if not _valid_world_file(file):
		return false
	var path := WORLDS_DIR + file + ".json"
	var data := _read_world(path)
	if data.is_empty():
		return false
	world_file = file
	world = data
	if not _valid_world_data(_read_json(path)):
		Events.notify("Мир восстановлен из резервной копии", Color.ORANGE)
	if not world.has("players"):
		world.players = {}
	world_loaded.emit()
	return true


func save_world() -> bool:
	if world_file == "":
		return false
	last_save_error = ""
	before_save.emit()
	world["saved"] = Time.get_datetime_string_from_system()
	var path := WORLDS_DIR + world_file + ".json"
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return _save_failed(FileAccess.get_open_error())
	f.store_string(JSON.stringify(world, "\t"))
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK:
		return _save_failed(err)
	# Never replace a good backup with a damaged primary file.
	if _valid_world_data(_read_json(path)):
		err = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if err == OK:
			err = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if err != OK:
			return _save_failed(err)
	err = DirAccess.rename_absolute(path + ".tmp", path)
	if err != OK:
		return _save_failed(err)
	return true


func _save_failed(err: Error) -> bool:
	last_save_error = error_string(err)
	Events.notify("Не удалось сохранить мир: " + last_save_error, Color.TOMATO)
	return false


func _valid_world_file(file: String) -> bool:
	return not file.is_empty() and file != "." and file != ".." and file == file.get_file() and file == file.validate_filename()


func _read_world(path: String) -> Dictionary:
	var data := _read_json(path)
	if not _valid_world_data(data):
		data = _read_json(path + ".bak")
	if not _valid_world_data(data):
		return {}
	return data


func _valid_world_data(data: Dictionary) -> bool:
	return not data.is_empty() and data.get("players", {}) is Dictionary


func delete_world(file: String) -> void:
	if not _valid_world_file(file):
		return
	for suffix in [".json", ".json.bak", ".json.tmp", ".json.bak.tmp"]:
		DirAccess.remove_absolute(WORLDS_DIR + file + suffix)


func close_world() -> void:
	world_file = ""
	world = {}


func world_display_name() -> String:
	return world.get("name", world_file)


func get_player(pid: String) -> Dictionary:
	return (world.get("players", {}) as Dictionary).get(pid, {})


func set_player(pid: String, data: Dictionary) -> void:
	if world_file == "":
		return
	world.players[pid] = data


func get_section(key: String) -> Dictionary:
	return world.get(key, {})


func set_section(key: String, data) -> void:
	world[key] = data


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
