class_name VillageClinic
extends Node3D

var doctor: CharacterModel
var beacon: AudioStreamPlayer3D
var _bell_t := 0.0

func _ready() -> void:
	name = "Clinic"
	transform = Layout.xform("hospital")
	add_to_group("clinic")
	add_to_group("poi")
	set_meta("poi_name", "Больница · фельдшерская")
	set_meta("poi_spot", "hospital")
	var st := Node3D.new()
	st.name = "Static"
	add_child(st)
	Build.room(st, 8, 6, 3.2, Art.color(Color(0.74,0.8,0.75)), Art.color(Color(0.84,0.9,0.86)),
		Art.color(Color(0.45,0.54,0.51)), Art.color(Color(0.25,0.36,0.35)), 2.0)
	Build.block(st, Vector3(0,-0.25,0), Vector3(8.4,0.5,6.4), Art.color(Color(0.4,0.45,0.42)))
	Build.text(st, Vector3(0,2.8,3.15), "БОЛЬНИЦА · 24 ЧАСА", 38, Color(0.6,1,0.75), 0.007)
	Build.block(st, Vector3(2.9,2.2,3.15), Vector3(0.2,0.8,0.05), Art.color(Color(0.2,0.85,0.5)),false)
	Build.block(st, Vector3(2.9,2.2,3.15), Vector3(0.7,0.2,0.05), Art.color(Color(0.2,0.85,0.5)),false)
	Build.lamp(st, Vector3(0,2.7,1.5),1.4,7,Color(0.8,1,0.88))
	doctor = Build.person(self, Vector3(1.2,0,2.5), PI, {"shirt":7,"pants":3,"hat":0,"skin":1}, "cashier")
	doctor.female = true
	doctor.restyle()
	Chatter.attach.call_deferred(doctor,"f",["У нас приём без записи. И без самогона, пожалуйста.",
		"Доктор сказал: меньше пить. Я уточнила: гораздо меньше."],2.3,6,"doctor")
	var area := Build.talk_area(self,Vector3(0,1.0,3.8),Vector3(4.0,2.5,3.8),self)
	area.name = "Treatment"
	beacon = AudioStreamPlayer3D.new()
	beacon.stream = Sfx.stream_of("bell")
	beacon.bus = "Effects"
	beacon.unit_size = 45
	beacon.max_distance = 260
	beacon.volume_db = -9
	beacon.position = Vector3(0,2,3)
	add_child(beacon)

func get_prompt(_p: Node) -> String:
	return "Фельдшер: вернуть зрение и подлечиться (бесплатно)" if Inventory.blindness > 0 else "Фельдшер: осмотр и перевязка"

func interact(p: Node) -> void:
	if p.global_position.distance_to(to_global(Vector3(0,0,3.8))) > 7:
		return
	var was_blind := Inventory.blindness > 0
	Inventory.blindness = 0.0
	Inventory.health = maxf(Inventory.health,80.0)
	Inventory.drunk = minf(Inventory.drunk,35.0)
	Inventory.changed.emit()
	Events.notify("Фельдшер: «Зрение вернулось. Теперь смотри, что пьёшь!»" if was_blind else "Фельдшер: «Жить будешь. Следующий!»",Color.PALE_GREEN)
	Sfx.play("cash",null,-15)

func _process(delta: float) -> void:
	_bell_t -= delta
	if Sfx.menus_block_voice() or Inventory.blindness <= 0.0:
		beacon.stop()
		return
	if _bell_t <= 0.0:
		_bell_t = 4.5
		beacon.play()

func help_line(player: Node3D) -> String:
	var local := player.global_basis.inverse() * (global_position-player.global_position)
	var side := "справа" if local.x > 0 else "слева"
	if absf(local.x) < absf(local.z) * 0.6:
		side = "впереди" if local.z < 0 else "позади"
	return "Колокольчик больницы %s. Подойди к крыльцу и нажми %s." % [side,Controls.key_label("interact")]
