class_name MeshBaker
extends RefCounted
## Оптимизация: склеивает неподвижные кусочки построек/деревьев/улицы в несколько больших мешей
## (по материалу и по квадратам CHUNK×CHUNK м, чтобы не терялась отсечка по камере).
## Было ~6800 отдельных MeshInstance3D — каждый это отдельный вызов отрисовки (и ещё один для теней).
##
## Не трогаем то, что двигается или прячется: всё под узлом со своим скриптом (двери, NPC, мебель-улучшения,
## люди CharacterModel, предметы на полках), под узлом с meta "no_bake", невидимое, со шкурой/мультимешем.

const CHUNK := 32.0


static func bake(root: Node3D) -> int:
	var groups := {}     ## ключ -> {mat, shadow, list: [[mesh, xform]]}
	var victims: Array[MeshInstance3D] = []
	_collect(root, root, groups, victims)
	if victims.size() < 2:
		return 0
	var inv := root.global_transform.affine_inverse()
	var made := 0
	for key in groups:
		var g: Dictionary = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for e in g.list:
			var m: Mesh = e[0]
			for s in m.get_surface_count():
				st.append_from(m, s, inv * (e[1] as Transform3D))
				any = true
		if not any:
			continue
		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.name = "Baked%d" % made
		mi.mesh = mesh
		mi.material_override = g.mat
		mi.cast_shadow = g.shadow
		mi.visibility_range_end = g.detail_range
		root.add_child(mi)
		made += 1
	for v in victims:
		# коллизию (StaticBody3D под мешем) сохраняем — переносим к родителю
		for b in v.get_children():
			var gt := (b as Node3D).global_transform
			v.remove_child(b)
			v.get_parent().add_child(b)
			(b as Node3D).global_transform = gt
		v.get_parent().remove_child(v)
		v.free()
	return victims.size()


static func _collect(root: Node3D, n: Node, groups: Dictionary, victims: Array[MeshInstance3D], inherited_range := 0.0) -> void:
	for c in n.get_children():
		var detail_range := float(c.get_meta("bake_detail_range", inherited_range))
		if c.has_meta("no_bake") or c is CharacterModel or c is Label3D:
			continue
		if c != root and c.get_script() != null and not (c is MeshInstance3D) and not c.has_meta("bake_ok"):
			continue   # у узла своя логика — может двигаться/прятаться
		if c is Node3D and not (c as Node3D).visible:
			continue
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.get_script() == null and mi.mesh != null and mi.skeleton == NodePath("") \
					and _only_bodies(mi) and mi.get_groups().is_empty() and _plain(mi):
				var mat: Material = mi.material_override
				if mat == null and mi.mesh.get_surface_count() == 1:
					mat = mi.mesh.surface_get_material(0)
				if mat != null and mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) != null:
					mat = null
				if mat != null:
					var p := mi.global_position
					var key := "%d:%d:%d:%d:%s" % [mat.get_instance_id(), int(mi.cast_shadow), floori(p.x / CHUNK), floori(p.z / CHUNK), detail_range]
					if not groups.has(key):
						groups[key] = {"mat": mat, "shadow": mi.cast_shadow, "detail_range": detail_range, "list": []}
					groups[key].list.append([mi.mesh, mi.global_transform])
					victims.append(mi)
					continue
		_collect(root, c, groups, victims, detail_range)


static func _only_bodies(mi: Node) -> bool:
	for c in mi.get_children():
		if not (c is CollisionObject3D) or c.get_script() != null:
			return false
	return true


## Обычный меш без особых настроек (дальность видимости, слои, прозрачность через transparency и т.п.).
static func _plain(mi: MeshInstance3D) -> bool:
	return mi.visibility_range_end == 0.0 and mi.layers == 1 and mi.transparency == 0.0 and mi.gi_mode != GeometryInstance3D.GI_MODE_DYNAMIC
