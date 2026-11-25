class_name PlayerMischief
extends Node

const FISH_PLEA := "Не жарь меня! У меня ипотека и сорок мальков!"
const FISH_INSULT := "Лох, я бы тебя съела!"
const WITNESS_FINE := "Гражданин, это убийство свидетеля! Штраф триста пятьдесят рублей."

var player: CharacterBody3D
var bucket_left := 0.0
var stunt_left := 0.0
var rocket_cooldown := 0.0
var _stunt_kind := ""
var _start := Vector3.ZERO
var _landing := Vector3.ZERO
var _ragdoll: ComicRagdoll
var _old_camera := false
var _sight := 0.0
var _shade: ColorRect
var _hint: Label
var _bucket_model: Node3D
var _panel: ModalUi
var _talking_entry: Dictionary = {}
var _prank_t := 100.0
var _prank_model: Node3D
var _loot_t := 0.0
var _surprise_t := 135.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	add_to_group("mischief")
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_shade)
	var info := CanvasLayer.new()
	info.layer = 9
	add_child(info)
	_hint = UiKit.label("",18,Color(1,0.9,0.65))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = -150
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_hint)
	_panel = ModalUi.new()
	add_child(_panel)
	_panel._setup("mischief_ui","",640)
	_prank_t = randf_range(140,260)

func _process(delta: float) -> void:
	rocket_cooldown = maxf(rocket_cooldown-delta,0)
	var had_bucket := bucket_left>0
	bucket_left = maxf(bucket_left-delta,0)
	if had_bucket and bucket_left<=0:
		Inventory.add_item("tool",&"bucket",1,false)
	if bucket_left <= 0 and is_instance_valid(_bucket_model):
		_bucket_model.queue_free()
		_bucket_model = null
	var covered := bucket_left > 0 or Inventory.blindness > 0
	_sight = move_toward(_sight,1.0 if covered else 0.0,delta*0.65)
	_shade.color = Color(0.01,0.012,0.014,_sight*0.998)
	var menus := Sfx.menus_block_voice()
	_shade.visible = not menus and _sight > 0.001
	_hint.visible = not menus and covered
	if bucket_left > 0:
		_hint.text = "ВЕДРО НА ГОЛОВЕ · %s → «Снять ведро»" % Controls.key_label("radial")
	elif Inventory.blindness > 0:
		_hint.text = "Не вижу! Самогон оказался с сюрпризом.\n%s → «Позвать врача». Лечение в больнице бесплатное." % Controls.key_label("radial")
	if stunt_left > 0:
		_tick_stunt(delta)
	if menus or Events.ui_open or stunt_left > 0:
		return
	_loot_t -= delta
	if _loot_t <= 0:
		_loot_t = 2
		var goose := get_tree().get_first_node_in_group("goose")
		if goose == null or goose.target_peer != multiplayer.get_unique_id():
			return_loot()
	_prank_t -= delta
	if _prank_t <= 0 and not player.swimming and not player.vehicle and not player.is_busy_body():
		_prank_t = randf_range(240,420)
		prank_mermaid()
	_surprise_t -= delta
	if _surprise_t <= 0 and not player.is_busy_body():
		_surprise_t = randf_range(180,300)
		var dc := get_tree().get_first_node_in_group("day_cycle")
		var today: int = dc.day if dc else 1
		if int(Inventory.stats.get("sky_snack_day",0)) != today:
			Inventory.stats["sky_snack_day"] = today
			var gift := SkySnack.new()
			player.get_parent().get_parent().add_child(gift)
			gift.global_position = NpcMotion.safe_point(player.global_position-player.global_basis.z*2)+Vector3.UP*8
			Events.notify("Небесная столовая выдала чебурек. Подбери, пока не остыл. Роспотребнадзор уже выехал.",Color.GOLD,false)

func on_drink(drink_id: StringName) -> void:
	if drink_id == &"samogon":
		Inventory.blindness = 1.0
		Inventory.stat_add("samogon_blindness")
		Inventory.changed.emit()
		Events.notify("Самогон «Тёмная лошадка»: свет погас. В больнице звенит колокольчик. Q — позвать врача.",Color.ORANGE,false)
	if Inventory.drunk >= 99.9:
		try_rocket()

func call_doctor() -> void:
	var clinic := get_tree().get_first_node_in_group("clinic")
	if clinic:
		clinic._bell_t = 0
		Events.notify(clinic.help_line(player),Color.PALE_GREEN,false)

func drop_bucket() -> bool:
	if not Inventory.remove_item("tool",&"bucket",1):
		return false
	var bucket := RigidBody3D.new()
	bucket.collision_layer = 0
	bucket.collision_mask = 1
	player.get_parent().get_parent().add_child(bucket)
	bucket.global_position = player.head.global_position-player.global_basis.z*0.7
	bucket.add_child(ItemModels.build("tool",&"bucket"))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.25
	sh.height = 0.4
	cs.shape = sh
	bucket.add_child(cs)
	bucket.linear_velocity = Vector3.UP*4.0
	get_tree().create_timer(3).timeout.connect(bucket.queue_free)
	if randf() < 0.6:
		wear_bucket()
	else:
		Inventory.add_item("tool",&"bucket",1,false)
		Events.notify("Ведро грохнулось рядом. В этот раз голову пронесло.",Color.LIGHT_GRAY,false)
	return true

func wear_bucket() -> void:
	bucket_left = 24
	if not is_instance_valid(_bucket_model):
		_bucket_model = ItemModels.build("tool",&"bucket")
		player.model.head.add_child(_bucket_model)
		_bucket_model.rotation.x = PI
		_bucket_model.position.y = 0.25
	Events.notify("Ведро: ТОНК! Все ржут. Q — снять ведро.",Color.ORANGE,false)
	Sfx.say(Vector3.ZERO,"m", "Ха-ха! Ведро тебе идёт! Почти депутат!","fish")

func remove_bucket() -> void:
	if bucket_left <= 0:
		return
	bucket_left = 0
	Inventory.add_item("tool",&"bucket",1,false)
	Events.notify("Снял ведро. Депутатские полномочия прекращены.",Color.PALE_GREEN,false)

func try_rocket() -> bool:
	if rocket_cooldown > 0 or stunt_left > 0 or player.sleeping or player._knocked_out or player.jail_left() > 0 or Inventory.health <= 0:
		return false
	if player.vehicle:
		player.vehicle.request_exit()
		player.exit_vehicle(false)
	if player.hidden:
		player.exit_hide()
	player.fishing.cancel()
	if player.carrying:
		player.drop_box("")
	_start = player.global_position
	var club := get_tree().root.get_node_or_null("World/StripClub")
	_landing = club.to_global(Vector3(0,0.25,3)) if club and randf()<0.25 else NpcMotion.safe_point(Layout.ring(randf_range(-175,175),5))
	stunt_left = 4.0
	_stunt_kind = "rocket"
	rocket_cooldown = 180
	Inventory.drunk = 68
	Inventory.stat_add("rocket_flights")
	_old_camera = player.third_person
	player.third_person = true
	player._apply_camera_mode()
	player.velocity = Vector3.ZERO
	Sfx.say(Vector3.ZERO,"m_low","За Родину!","fish")
	Events.notify("ДЕД РОСКОСМОСА: ЗА РОДИНУ!",Color.GOLD,false)
	return true

func start_ragdoll() -> bool:
	if stunt_left > 0 or player.vehicle or player.swimming or player.sleeping or player._knocked_out:
		return false
	player.fishing.cancel()
	_stunt_kind = "ragdoll"
	stunt_left = 2.6
	_old_camera = player.third_person
	player.third_person = true
	player._apply_camera_mode()
	player.body.visible = false
	player.fp_hand.visible = false
	var effects := get_tree().get_first_node_in_group("village_mayhem")
	if effects:
		effects.request_ragdoll(player.global_position)
	_ragdoll = ComicRagdoll.new()
	_ragdoll.palette = {"shirt":player.model.shirt,"skin":player.model.skin,"pants":player.model.pants}
	get_tree().root.add_child(_ragdoll)
	_ragdoll.global_position = player.global_position
	_landing = player.global_position
	player.velocity = Vector3.ZERO
	Sfx.say(Vector3.ZERO,"m_low","Ай! Я не мешок картошки!","fish")
	return true

func _tick_stunt(delta: float) -> void:
	stunt_left = maxf(stunt_left-delta,0)
	if _stunt_kind == "rocket":
		var t := 1-stunt_left/4.0
		player.global_position = _start.lerp(_landing,t)+Vector3.UP*sin(t*PI)*27
		player.model.rotation.z = sin(t*PI*6)*0.25
	else:
		if is_instance_valid(_ragdoll) and is_instance_valid(_ragdoll.torso):
			_landing = _ragdoll.torso.global_position
	if stunt_left <= 0:
		if _stunt_kind == "ragdoll":
			player.global_position = NpcMotion.safe_point(_landing)
			player.body.visible = true
		player.third_person = _old_camera
		player.model.rotation.z = 0
		player._apply_camera_mode()
		player.refresh_held()
		player.velocity = Vector3.ZERO
		player.input_cooldown = 0.3
		_stunt_kind = ""

func offer_fish(entry: Dictionary) -> void:
	entry["talking"] = true
	_talking_entry = entry
	ModalUi.clear(_panel.body)
	_panel.body.add_child(UiKit.title("РЫБА-ГОВОРУН"))
	var label := UiKit.label(FISH_PLEA,20,Color(0.8,1,0.9))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.body.add_child(label)
	_panel.body.add_child(UiKit.button("Отпустить", release_fish))
	_panel.body.add_child(UiKit.button("Зажарить", fry_fish))
	_panel.body.add_child(UiKit.button("Оставить в садке", _panel.close))
	_panel._show()
	Sfx.say(Vector3.ZERO,"m",FISH_PLEA,"fish")

func _fish_index() -> int:
	for i in Inventory.basket.size():
		if is_same(Inventory.basket[i],_talking_entry):
			return i
	return -1

func release_fish() -> void:
	var i := _fish_index()
	if i < 0:
		_panel.close()
		return
	Inventory.remove_fish(i)
	_panel.close()
	Events.notify("Рыба: «%s»" % FISH_INSULT,Color.AQUAMARINE,false)
	Sfx.say(Vector3.ZERO,"m",FISH_INSULT,"fish")
	Sfx.play("splash",player.global_position)

func fry_fish() -> void:
	var i := _fish_index()
	if i < 0:
		_panel.close()
		return
	Inventory.remove_fish(i)
	Inventory.satiety = minf(Inventory.satiety+30,100)
	Inventory.health = minf(Inventory.health+10,100)
	var fine := mini(350,Inventory.money)
	Inventory.money -= fine
	Inventory.stat_add("fined",fine)
	Inventory.changed.emit()
	_panel.close()
	Events.notify("Петрович: убийство свидетеля! Штраф %d ₽. Рыба вкусная, статья неприятная." % fine,Color.ORANGE,false)
	Sfx.say(Vector3.ZERO,"m_low",WITNESS_FINE,"fish")

func goose_peck() -> void:
	if Inventory.held_rod_slot() and randf()<0.35:
		Inventory.wear_rod(12)
		Events.notify("Гусь клюнул снасть! Посмотри, цела ли удочка.",Color.ORANGE,false)
		Inventory.changed.emit()
	else:
		for i in Inventory.SLOTS:
			var s = Inventory.slot(i)
			if s and s.kind in ["food","bait","drink"]:
				Inventory.goose_loot.append({"kind":s.kind,"id":String(s.id),"count":1})
				Inventory.remove_slot(i,1)
				Events.notify("Гусь отжал %s! Q → откупиться хлебом. Всё украденное вернётся." % GameData.item_name(s.kind,s.id),Color.ORANGE,false)
				break
	Inventory.damage(2)

func return_loot() -> void:
	for i in range(Inventory.goose_loot.size()-1,-1,-1):
		var item: Dictionary = Inventory.goose_loot[i]
		if Inventory.add_item(item.kind,StringName(item.id),int(item.count),false):
			Inventory.goose_loot.remove_at(i)

func prank_mermaid() -> void:
	if is_instance_valid(_prank_model):
		return
	_prank_model = Node3D.new()
	get_tree().root.add_child(_prank_model)
	_prank_model.global_position = NpcMotion.safe_point(player.global_position-player.global_basis.z*3)
	var model := Build.person(_prank_model,Vector3.ZERO,0,{"shirt":9,"pants":3,"hat":1,"hat_color":1},"seller")
	model.look_at(Vector3(player.global_position.x,model.global_position.y,player.global_position.z),Vector3.UP,true)
	Art.add_mesh(_prank_model,Art.cyl(0.12,0.36,0.9,10),Art.color(Color(0.2,0.8,0.65)),Vector3(0,0.45,0))
	Build.text(_prank_model,Vector3(0,2.3,0),"РУСАЛКА ПРИ ИСПОЛНЕНИИ",32,Color.AQUAMARINE,0.006,0,true)
	Events.notify("Из кустов вылез Семёныч в хвосте русалки. Требует улов. Q — попросить документы.",Color.AQUAMARINE,false)
	Sfx.say(Vector3.ZERO,"m_low","Кря! Предъявите улов! Я русалка при исполнении!","fish")
	get_tree().create_timer(18).timeout.connect(func() -> void:
		if is_instance_valid(_prank_model):
			_prank_model.queue_free()
			_prank_model = null)

func answer_prank(give_fish := false) -> void:
	if not is_instance_valid(_prank_model):
		return
	if give_fish and not Inventory.basket.is_empty():
		Inventory.remove_fish(0)
		Events.notify("Семёныч спрятал рыбку в хвост: «Конфисковано в пользу морской пехоты!»",Color.AQUAMARINE,false)
	else:
		Events.notify("Семёныч показал корочку: «Русалка третьего разряда». И удалился боком.",Color.AQUAMARINE,false)
	_prank_model.queue_free()
	_prank_model = null

func _exit_tree() -> void:
	for prop in [_ragdoll,_prank_model]:
		if is_instance_valid(prop):
			prop.queue_free()


class SkySnack extends RigidBody3D:
	var taken := false
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		continuous_cd = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.35,0.16,0.35)
		shape.shape = box
		add_child(shape)
		add_child(ItemModels.build("food",&"cheburek"))
		var pick := SnackPickup.new()
		add_child(pick)
		get_tree().create_timer(90).timeout.connect(queue_free)
	func collect() -> void:
		if not taken and Inventory.add_item("food",&"cheburek"):
			taken = true
			Events.notify("Подобрал чебурек небесного происхождения. Документов у него нет.",Color.PALE_GREEN,false)
			queue_free()

class SnackPickup extends Interactable:
	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.7
		cs.shape = sh
		add_child(cs)
	func get_prompt(_p: Node) -> String:
		return "Небесный чебурек · подобрать"
	func interact(_p: Node) -> void:
		get_parent().collect()
