out = ['[gd_scene format=3]', '']
scripts = [("world","res://scripts/world/world.gd"),("decor","res://scripts/world/decor.gd"),
 ("terrain","res://scripts/world/terrain.gd"),("water","res://scripts/world/water.gd"),("reeds","res://scripts/world/reeds.gd"),
 ("ladder","res://scripts/world/ladder.gd"),("door","res://scripts/world/shop/auto_door.gd"),("book","res://scripts/world/shop/fish_book.gd"),
 ("shopitem","res://scripts/world/shop/shop_item.gd"),("shop","res://scripts/world/shop/shop.gd"),
 ("cashier","res://scripts/world/shop/cashier.gd"),("guard","res://scripts/world/shop/guard.gd"),
 ("model","res://scripts/art/character_model.gd"),("delegate","res://scripts/world/delegate_interactable.gd"),
 ("trader","res://scripts/world/market/trader.gd"),("bottles","res://scripts/world/bottles.gd"),("mess","res://scripts/world/mess.gd"),
 ("hud","res://scripts/ui/hud.gd"),("traderui","res://scripts/ui/trader_ui.gd"),("bookui","res://scripts/ui/fish_book_ui.gd"),
 ("invui","res://scripts/ui/inventory_ui.gd"),("pause","res://scripts/ui/pause_menu.gd"),("menu","res://scripts/ui/main_menu.gd"),
 ("daycycle","res://scripts/world/day_cycle.gd"),("combat","res://scripts/world/combat.gd"),("house","res://scripts/world/places/house.gd"),
 ("liquor","res://scripts/world/places/liquor_store.gd"),("casino","res://scripts/world/places/casino.gd"),
 ("thimble","res://scripts/world/npc/thimble_man.gd"),("small","res://scripts/world/places/small_places.gd"),
 ("loader","res://scripts/world/places/loader_job.gd"),("street","res://scripts/world/places/street.gd"),
 ("hiding","res://scripts/world/places/hiding_spot.gd"),("grass","res://scripts/world/grass.gd"),
 ("casinoui","res://scripts/ui/casino_ui.gd"),("storeui","res://scripts/ui/store_ui.gd"),("giveui","res://scripts/ui/give_ui.gd"),
 ("mapui","res://scripts/ui/map_ui.gd"),("dayui","res://scripts/ui/day_ui.gd"),
 ("weather","res://scripts/world/weather.gd"),("tourn","res://scripts/world/tournament.gd"),
 ("moon","res://scripts/world/places/moonshine.gd"),("vehicle","res://scripts/world/vehicle.gd"),
 ("police_st","res://scripts/world/places/police_station.gd"),("police","res://scripts/world/npc/police.gd"),
 ("babka","res://scripts/world/npc/babka.gd"),("house_up","res://scripts/world/places/house_upgrades.gd"),
 ("houseui","res://scripts/ui/house_ui.gd"),("settingsui","res://scripts/ui/settings_ui.gd"),("bribeui","res://scripts/ui/bribe_ui.gd"),("disputeui","res://scripts/ui/dispute_ui.gd"),
 ("nets","res://scripts/world/nets.gd"),("inspector","res://scripts/world/npc/inspector.gd"),("tsar","res://scripts/world/tsar_sighting.gd"),
 ("farm","res://scripts/world/places/farm.gd"),("cow","res://scripts/world/npc/cow.gd"),("club","res://scripts/world/places/club.gd"),
 ("brawler","res://scripts/world/npc/brawler.gd"),("repair","res://scripts/world/places/repair_job.gd"),("repairui","res://scripts/ui/repair_ui.gd")]
for k,p in scripts: out.append(f'[ext_resource type="Script" path="{p}" id="s_{k}"]')
texs = ["plaster","tiles","planks","roof","sign_shop","sign_market","asphalt"]
for t in texs: out.append(f'[ext_resource type="Texture2D" path="res://art/textures/{t}.png" id="t_{t}"]')
out.append('')
def texmat(name, tex, scale=0.5, extra=""):
    out.extend([f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]', f'albedo_texture = ExtResource("t_{tex}")',
        'uv1_triplanar = true', 'uv1_world_triplanar = true', f'uv1_scale = Vector3({scale}, {scale}, {scale})', 'roughness = 0.9'] + ([extra] if extra else []) + [''])
def colmat(name, c, extra=""):
    out.extend([f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]', f'albedo_color = Color({c})'] + ([extra] if extra else []) + [''])
texmat("wall","plaster",0.4); texmat("inner","plaster",0.5,"albedo_color = Color(1, 0.97, 0.9, 1)"); texmat("tile","tiles",0.45)
texmat("wood","planks",0.5); texmat("darkwood","planks",0.6,"albedo_color = Color(0.6, 0.5, 0.45, 1)"); texmat("roof","roof",0.35)
texmat("stone","asphalt",0.5)
colmat("red","0.82, 0.12, 0.12, 1"); colmat("green","0.12, 0.5, 0.22, 1"); colmat("metal","0.6, 0.62, 0.65, 1","metallic = 0.6\nroughness = 0.35")
colmat("shelf","0.92, 0.91, 0.88, 1","metallic = 0.1\nroughness = 0.6"); colmat("glass","0.3, 0.45, 0.55, 0.6","transparency = 1\nmetallic = 0.4\nroughness = 0.1")
colmat("lamp","1, 1, 0.95, 1","emission_enabled = true\nemission = Color(1, 0.98, 0.9, 1)\nemission_energy_multiplier = 2.0")
colmat("awning","0.2, 0.45, 0.8, 1"); colmat("awning2","0.95, 0.95, 0.95, 1"); colmat("fish","0.7, 0.75, 0.78, 1","metallic = 0.5\nroughness = 0.3")
colmat("ice","0.85, 0.93, 1, 1","roughness = 0.2")
for k,t in [("sign_shop","sign_shop"),("sign_market","sign_market")]:
    out.extend([f'[sub_resource type="StandardMaterial3D" id="Mat_{k}"]', f'albedo_texture = ExtResource("t_{t}")','emission_enabled = true', f'emission_texture = ExtResource("t_{t}")','emission_energy_multiplier = 0.4',''])
    out.extend([f'[sub_resource type="QuadMesh" id="Quad_{k}"]', f'material = SubResource("Mat_{k}")', 'size = Vector2(6, 1.3)' if k=="sign_shop" else 'size = Vector2(3, 0.65)',''])
out += ['[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]',
 'sky_top_color = Color(0.28, 0.48, 0.8, 1)', 'sky_horizon_color = Color(0.68, 0.78, 0.88, 1)',
 'ground_bottom_color = Color(0.2, 0.25, 0.2, 1)', 'ground_horizon_color = Color(0.68, 0.78, 0.88, 1)', 'sun_angle_max = 20.0','',
 '[sub_resource type="Sky" id="Sky"]', 'sky_material = SubResource("SkyMat")', '',
 '[sub_resource type="Environment" id="Env"]', 'background_mode = 2', 'sky = SubResource("Sky")',
 'ambient_light_source = 3', 'ambient_light_energy = 1.0', 'tonemap_mode = 3', 'tonemap_white = 6.0',
 'ssao_enabled = true', 'ssao_radius = 1.2', 'ssao_intensity = 1.6', 'ssil_enabled = true', 'ssil_intensity = 0.8',
 'glow_enabled = true', 'glow_intensity = 0.4', 'glow_strength = 0.9', 'glow_bloom = 0.0', 'glow_blend_mode = 1', 'glow_hdr_threshold = 1.2',
 'fog_enabled = true', 'fog_light_color = Color(0.72, 0.8, 0.88, 1)', 'fog_density = 0.0015', 'fog_sky_affect = 0.3',
 'adjustment_enabled = true', 'adjustment_saturation = 1.14', 'adjustment_contrast = 1.06', '',
 '[sub_resource type="CapsuleShape3D" id="NpcShape"]', 'radius = 0.4', 'height = 1.9', '',
 '[sub_resource type="CapsuleShape3D" id="TalkShape"]', 'radius = 0.55', 'height = 2.0', '',
 '[sub_resource type="BoxShape3D" id="LadderShape"]', 'size = Vector3(1.2, 1.6, 1.0)', '',
 '[sub_resource type="BoxShape3D" id="BookShape"]', 'size = Vector3(0.8, 1.4, 0.8)', '',
 '''[sub_resource type="SceneReplicationConfig" id="GuardRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:talker")
properties/3/spawn = true
properties/3/replication_mode = 2
properties/4/path = NodePath(".:hp")
properties/4/spawn = true
properties/4/replication_mode = 2
''',
 '''[sub_resource type="SceneReplicationConfig" id="TraderRepl"]
properties/0/path = NodePath(".:drunk")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:mood")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:asleep_time")
properties/2/spawn = true
properties/2/replication_mode = 1
properties/3/path = NodePath(".:angry_time")
properties/3/spawn = true
properties/3/replication_mode = 1
properties/4/path = NodePath(".:strikes")
properties/4/spawn = true
properties/4/replication_mode = 2
properties/5/path = NodePath(".:drink_anim")
properties/5/spawn = true
properties/5/replication_mode = 1
properties/6/path = NodePath(".:drink_id")
properties/6/spawn = true
properties/6/replication_mode = 2
properties/7/path = NodePath(".:hurt_time")
properties/7/spawn = true
properties/7/replication_mode = 1
''',
 '''[sub_resource type="SceneReplicationConfig" id="DayRepl"]
properties/0/path = NodePath(".:minutes")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:day")
properties/1/spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:phase")
properties/2/spawn = true
properties/2/replication_mode = 2
''',
 '''[sub_resource type="SceneReplicationConfig" id="GoshaRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:hp")
properties/3/spawn = true
properties/3/replication_mode = 2
''']
out += [
'''[sub_resource type="SceneReplicationConfig" id="WeatherRepl"]
properties/0/path = NodePath(".:state")
properties/0/spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:next_state")
properties/1/spawn = true
properties/1/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="TournRepl"]
properties/0/path = NodePath(".:active")
properties/0/spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:leader_name")
properties/1/spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:leader_fish")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:leader_kg")
properties/3/spawn = true
properties/3/replication_mode = 2
properties/4/path = NodePath(".:prize")
properties/4/spawn = true
properties/4/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="HouseRepl"]
properties/0/path = NodePath(".:upgrades")
properties/0/spawn = true
properties/0/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="PoliceRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:target_name")
properties/3/spawn = true
properties/3/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="CowRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:graze_left")
properties/3/spawn = true
properties/3/replication_mode = 1
properties/4/path = NodePath(".:herder_name")
properties/4/spawn = true
properties/4/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="ClubRepl"]
properties/0/path = NodePath(".:kind")
properties/0/spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:stage")
properties/1/spawn = true
properties/1/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="BrawlRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:active")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:down")
properties/3/spawn = true
properties/3/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="InspRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:siren")
properties/3/spawn = true
properties/3/replication_mode = 2
''',
'''[sub_resource type="SceneReplicationConfig" id="MoonRepl"]
properties/0/path = NodePath(".:stage")
properties/0/spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:left")
properties/1/spawn = true
properties/1/replication_mode = 1
''',
'''[sub_resource type="SceneReplicationConfig" id="VehRepl"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:speed")
properties/2/spawn = true
properties/2/replication_mode = 1
properties/3/path = NodePath(".:occupants")
properties/3/spawn = true
properties/3/replication_mode = 2
properties/4/path = NodePath(".:rented_day")
properties/4/spawn = true
properties/4/replication_mode = 2
properties/5/path = NodePath(".:capsized")
properties/5/spawn = true
properties/5/replication_mode = 2
properties/6/path = NodePath(".:steer_vis")
properties/6/spawn = true
properties/6/replication_mode = 1
'''
]
def node(name, typ, parent=None, props=(), extra=''):
    p = f' parent="{parent}"' if parent else ''
    out.append(f'[node name="{name}" type="{typ}"{p}{extra}]'); out.extend(props); out.append('')
def v3(x,y,z): return f"Vector3({x}, {y}, {z})"
def csg(name, parent, pos, size, mat, coll=True, extra_props=()):
    props = [f'position = {v3(*pos)}', f'size = {v3(*size)}', f'material = SubResource("Mat_{mat}")']
    if coll: props += ['use_collision = true', 'collision_mask = 0']
    node(name, "CSGBox3D", parent, props + list(extra_props))
def label(name, parent, pos, text, size, color="Color(1, 1, 1, 1)", billboard=False, px=0.01, roty=None):
    props=[f'position = {v3(*pos)}'] + ([f'rotation = Vector3(0, {roty}, 0)'] if roty is not None else []) + [ f'text = "{text}"', f'font_size = {size}', f'pixel_size = {px}', f'modulate = {color}', 'outline_size = 16', 'outline_modulate = Color(0, 0, 0, 0.7)']
    if billboard: props.append('billboard = 1')
    node(name, "Label3D", parent, props)
def model(parent, **kw):
    props=['script = ExtResource("s_model")']
    for k,v in kw.items(): props.append(f'{k} = {v}')
    node("Visual","Node3D",parent,props)
def talk_area(parent, y=0.95, shape="TalkShape"):
    node("TalkArea","Area3D",parent,['script = ExtResource("s_delegate")'])
    node("Shape","CollisionShape3D",f"{parent}/TalkArea",[f'position = Vector3(0, {y}, 0)',f'shape = SubResource("{shape}")'])
def status_label(parent, y=2.25):
    node("Status","Label3D",parent,[f'position = Vector3(0, {y}, 0)','billboard = 1','no_depth_test = true','font_size = 34','pixel_size = 0.006','outline_size = 10','text = ""'])
C=lambda r,g,b: f"Color({r}, {g}, {b}, 1)"

node("World", "Node3D", None, ['script = ExtResource("s_world")'])
node("WorldEnvironment", "WorldEnvironment", ".", ['environment = SubResource("Env")'])
node("Sun", "DirectionalLight3D", ".", ['rotation = Vector3(-0.85, 0.75, 0)', 'light_color = Color(1, 0.96, 0.88, 1)', 'light_energy = 1.25', 'shadow_enabled = true', 'directional_shadow_max_distance = 70.0'])
node("Moon", "DirectionalLight3D", ".", ['rotation = Vector3(-0.9, -2.2, 0)', 'light_color = Color(0.62, 0.72, 1, 1)', 'light_energy = 0.0', 'shadow_enabled = true', 'directional_shadow_max_distance = 50.0', 'visible = false'])
node("DayCycle", "Node", ".", ['script = ExtResource("s_daycycle")'])
node("Sync", "MultiplayerSynchronizer", "DayCycle", ['root_path = NodePath("..")', 'replication_config = SubResource("DayRepl")'])
node("Combat", "Node", ".", ['script = ExtResource("s_combat")'])
node("Weather", "Node", ".", ['script = ExtResource("s_weather")'])
node("Sync", "MultiplayerSynchronizer", "Weather", ['replication_config = SubResource("WeatherRepl")'])
node("Tournament", "Node", ".", ['script = ExtResource("s_tourn")'])
node("Sync", "MultiplayerSynchronizer", "Tournament", ['replication_config = SubResource("TournRepl")'])
node("MenuCamera", "Camera3D", ".", ['position = Vector3(-2, 11, -40)', 'rotation = Vector3(-0.28, 3.14159, 0)', 'current = true'])
node("Terrain","StaticBody3D",".",['script = ExtResource("s_terrain")'])
node("Water","MeshInstance3D",".",['script = ExtResource("s_water")'])
node("Reeds","Node3D",".",['script = ExtResource("s_reeds")'])
# Пирс
P="Pier"
node(P,"Node3D",".",['position = Vector3(0, 0, -9.6)','metadata/poi_name = "Пирс"'],' groups=["poi"]')
csg("Deck",P,(0,0.08,0),(2.6,0.16,9),"wood")
for i,z in enumerate([-4.3,-2,0.5,3]):
    for x in (-1.15,1.15):
        csg(f"Post{i}_{int(x>0)}",P,(x,-1.6,z),(0.2,3.6,0.2),"darkwood",False)
for x in (-1.25,1.25):
    csg(f"Rail{int(x>0)}",P,(x,0.6,0.5),(0.08,0.08,8),"darkwood",False)
csg("Bench",P,(0,0.4,-3.6),(1.6,0.08,0.4),"wood",True)
node("Ladder","Node3D",P,['position = Vector3(0.6, -0.4, -4.75)','script = ExtResource("s_ladder")','top_point = Vector3(0, 0.75, 0.9)'])
for i in range(4):
    csg(f"Step{i}",f"{P}/Ladder",(0,-0.6+i*0.3,0),(0.5,0.04,0.06),"metal",False)
for x in (-0.25,0.25):
    csg(f"Side{int(x>0)}",f"{P}/Ladder",(x,-0.1,0),(0.04,1.4,0.04),"metal",False)
talk_area(f"{P}/Ladder",0.0,"LadderShape")
# Вывеска проката ставится из World._place_pier_sign() — доска на столбе, не огромный Label3D.

# ---------------- Шестёрочка (16 x 11)
S="Shop"
node(S,"Node3D",".",['position = Vector3(13, 0, -4)','script = ExtResource("s_shop")'])
node("Building","CSGCombiner3D",S,['use_collision = true','collision_mask = 0'])
csg("Outer",f"{S}/Building",(0,2.1,0),(16,4.2,11),"wall",False)
csg("Inner",f"{S}/Building",(0,1.9,0),(15.6,4.0,10.6),"inner",False,['operation = 2'])
csg("Door",f"{S}/Building",(0,1.2,5.5),(2.0,2.4,1.0),"inner",False,['operation = 2'])
csg("Base",S,(0,0.25,5.52),(16.1,0.5,0.06),"stone",False)
csg("Roof",S,(0,4.3,0),(16.6,0.25,11.6),"roof",False)
csg("Floor",S,(0,0.02,0),(15.6,0.04,10.6),"tile",False)
csg("Stripe",S,(0,3.55,5.53),(16,0.12,0.08),"green",False)
node("SignQuad","MeshInstance3D",S,['position = Vector3(0, 3.05, 5.56)','mesh = SubResource("Quad_sign_shop")'])
csg("WindowL",S,(-4.8,1.5,5.52),(4.2,1.6,0.08),"glass",False)
csg("WindowR",S,(4.8,1.5,5.52),(4.2,1.6,0.08),"glass",False)
csg("DoorFrame",S,(0,2.47,5.53),(2.2,0.1,0.1),"metal",False)
node("Doors","Node3D",S,['position = Vector3(0, 0, 5.5)','script = ExtResource("s_door")'])
for i,(x,z) in enumerate([(-4,-1.5),(4,-1.5),(-4,2.5),(4,2.5)]):
    csg(f"Lamp{i}",S,(x,3.85,z),(1.6,0.06,0.3),"lamp",False)
node("Light1","OmniLight3D",S,['position = Vector3(-3.5, 3.4, 0)','light_energy = 1.3','omni_range = 9.0'])
node("Light2","OmniLight3D",S,['position = Vector3(3.5, 3.4, 0)','light_energy = 1.3','omni_range = 9.0'])
# Стеллажи с алкоголем у задней стены
for side,x0 in (("A",-3.6),("B",3.6)):
    csg(f"Shelf{side}",S,(x0,1.1,-4.95),(6.4,2.2,0.08),"shelf",False)
    for k,y in enumerate([0.1,0.7,1.3,1.9]):
        csg(f"Shelf{side}_{k}",S,(x0,y,-4.7),(6.4,0.04,0.55),"shelf", k==0)
    csg(f"Shelf{side}_side0",S,(x0-3.2,1.1,-4.7),(0.05,2.2,0.55),"shelf",True)
    csg(f"Shelf{side}_side1",S,(x0+3.2,1.1,-4.7),(0.05,2.2,0.55),"shelf",True)
label("SignDrinks",S,(0,2.65,-4.9),"АЛКОГОЛЬ",44,"Color(1, 0.85, 0.5, 1)",False,0.004)
items=[]
for (x0,ids) in ((-3.6,["beer","strong_beer","cider"]),(3.6,["port","wine","vodka"])):
    for k,iid in enumerate(ids):
        y=[0.72,1.32,1.92][k]
        items.append(("drink",iid,(x0-1.55,y,-4.7),0,8,0.17))
        items.append(("drink",iid,(x0+1.55,y,-4.7),0,8,0.17))
    items.append(("drink",ids[0] if x0<0 else "vodka",(x0,0.12,-4.7),0,10,0.17))
# Левая стена — наживка и еда
csg("LeftShelf",S,(-7.5,1.1,-1.0),(0.08,2.2,7),"shelf",False)
for k,y in enumerate([0.1,0.7,1.3,1.9]):
    csg(f"LeftShelf_{k}",S,(-7.25,y,-1.0),(0.55,0.04,7),"shelf",k==0)
label("SignFood",S,(-7.4,2.65,-1.0),"НАЖИВКА · ПРОДУКТЫ",40,"Color(0.8, 1, 0.7, 1)",False,0.0038,1.5708)
rows=[[("bait","bread"),("bait","corn"),("bait","worm")],[("bait","maggot"),("bait","dough"),("bait","sausage")],[("food","noodles"),("food","crackers"),("food","cheburek")]]
for k,row in enumerate(rows):
    for j,(kind,iid) in enumerate(row):
        items.append((kind,iid,(-7.25,[0.72,1.32,1.92][k],-3.2+j*2.2),1,5,0.15))
# Островок со снеками по центру
csg("Island",S,(0,0.5,-0.5),(4.5,1.0,1.2),"shelf",True)
items.append(("food","crackers",(-1.2,1.0,-0.5),0,7,0.16))
items.append(("food","noodles",(1.2,1.0,-0.5),0,7,0.14))
items.append(("tool","flashlight",(0,1.0,-0.45),0,3,0.12))
items.append(("misc","sugar",(-1.1,1.0,-0.85),3,5,0.15))
items.append(("misc","yeast",(1.0,1.0,-0.85),3,6,0.11))
label("SignSale",S,(0,2.35,-0.5),"АКЦИЯ!",36,"Color(1, 0.3, 0.2, 1)",True,0.004)
# Удочки на правой стене
csg("RodRack",S,(7.7,1.3,-2.15),(0.08,2.6,4.9),"wood",False)
label("SignRods",S,(7.6,2.95,-2.3),"РЫБАЛКА · ОХОТА",40,"Color(0.7, 0.85, 1, 1)",False,0.0038,-1.5708)
for j,iid in enumerate(["bamboo","telescopic","spinning","carbon","feeder","sea"]):
    items.append(("rod",iid,(7.4,0,-4.35+j*0.72),2,2 if iid!="sea" else 1,0.18))
items.append(("weapon","bat",(7.4,0.05,0.0),2,2,0.2))
# Касса
# Касса вдоль правой стены: Зина стоит у стены лицом в зал.
csg("Counter",S,(5.9,0.5,3.2),(0.8,1.0,2.8),"red")
csg("CounterTop",S,(5.9,1.02,3.2),(0.9,0.05,2.9),"shelf",False)
csg("Register",S,(6.0,1.2,3.3),(0.4,0.3,0.5),"metal",False)
csg("CashBack",S,(7.75,1.5,3.2),(0.06,1.4,2.6),"red",False)
label("SignCash",S,(7.7,2.95,3.2),"КАССА",40,"Color(1, 1, 1, 1)",False,0.004,-1.5708)
items.append(("drink","cognac",(5.75,1.05,2.25),2,3,0.14))
items.append(("smoke","cigs",(5.75,1.05,4.25),2,4,0.08))
items.append(("food","shawarma",(5.75,1.05,3.8),2,1,0.15))
rot={0:"",1:"rotation = Vector3(0, 1.5708, 0)",2:"rotation = Vector3(0, -1.5708, 0)",3:"rotation = Vector3(0, 3.14159, 0)"}
for n,(kind,iid,pos,r,f,sp) in enumerate(items):
    props=[f'position = {v3(*pos)}','script = ExtResource("s_shopitem")',f'kind = "{kind}"',f'item_id = &"{iid}"',f'facings = {f}',f'spacing = {sp}']
    if rot[r]: props.insert(1,rot[r])
    node(f"Item{n}_{iid}","Area3D",S,props)
node("Cashier","Node3D",S,['position = Vector3(7.05, 0, 3.2)','rotation = Vector3(0, 1.5708, 0)','script = ExtResource("s_cashier")'])
model(f"{S}/Cashier", shirt=C(0.75,0.15,0.2), pants=C(0.2,0.2,0.25), hat=0, hair_color=C(0.55,0.2,0.1), face_name='"cashier"', height_scale=0.95)
talk_area(f"{S}/Cashier")
label("Name",f"{S}/Cashier",(0,2.1,0),"Зина",36,"Color(1, 1, 1, 0.8)",True,0.0055)
node("Book","Node3D",S,['position = Vector3(-6.2, 0, 3.8)','script = ExtResource("s_book")'])
talk_area(f"{S}/Book",0.7,"BookShape")
node("Guard","CharacterBody3D",S,['position = Vector3(-3.6, 0.05, 4.3)','collision_layer = 8','collision_mask = 5','script = ExtResource("s_guard")'])
node("Shape","CollisionShape3D",f"{S}/Guard",['position = Vector3(0, 0.95, 0)','shape = SubResource("NpcShape")'])
model(f"{S}/Guard", shirt=C(0.12,0.14,0.2), pants=C(0.1,0.1,0.12), hat=1, hat_color=C(0.08,0.08,0.1), face_name='"guard"', fat="true", height_scale=1.07)
talk_area(f"{S}/Guard")
status_label(f"{S}/Guard",2.4)
node("Sync","MultiplayerSynchronizer",f"{S}/Guard",['replication_config = SubResource("GuardRepl")'])

# ---------------- Рынок
M="Market"
node(M,"Node3D",".",['position = Vector3(-13, 0, 5.4)','metadata/poi_name = "Рынок · Дядя Толя"'],' groups=["poi"]')
csg("Table",M,(0,0.45,0),(3,0.9,1.2),"wood")
csg("Ice",M,(0,0.92,0.05),(2.8,0.06,1.0),"ice",False)
for i,(x,z) in enumerate([(-1.5,-0.6),(1.5,-0.6),(-1.5,0.8),(1.5,0.8)]):
    csg(f"Post{i}",M,(x,1.3,z),(0.12,2.6,0.12),"darkwood",False)
for i in range(6):
    csg(f"Awning{i}",M,(-1.42+i*0.57,2.62,0.1),(0.57,0.08,1.95),"awning" if i%2==0 else "awning2",False)
for i,x in enumerate([-0.9,-0.3,0.4,0.95]):
    csg(f"Fish{i}",M,(x,0.99,0.1),(0.42,0.07,0.15),"fish",False)
node("SignQuad","MeshInstance3D",M,['position = Vector3(0, 2.25, 1.08)','mesh = SubResource("Quad_sign_market")'])
csg("Crate1",M,(1.9,0.25,-0.6),(0.6,0.5,0.6),"wood",True)
csg("Crate2",M,(1.9,0.75,-0.6),(0.5,0.5,0.5),"wood",False)
node("Trader","Node3D",M,['position = Vector3(0, 0, -1.2)','rotation = Vector3(0, 3.14159, 0)','script = ExtResource("s_trader")'])
model(f"{M}/Trader", shirt=C(0.2,0.25,0.55), pants=C(0.25,0.22,0.18), hat=3, hat_color=C(0.35,0.28,0.2), face_name='"trader"', fat="true", stripes="true")
node("Body","StaticBody3D",f"{M}/Trader",['collision_layer = 8','collision_mask = 0'])
node("Shape","CollisionShape3D",f"{M}/Trader/Body",['position = Vector3(0, 0.95, 0)','shape = SubResource("NpcShape")'])
talk_area(f"{M}/Trader")
status_label(f"{M}/Trader",3.05)
node("Sync","MultiplayerSynchronizer",f"{M}/Trader",['replication_config = SubResource("TraderRepl")'])

# ---------------- Посёлок (v0.4)
PI="3.14159"
node("Street","Node3D",".",['script = ExtResource("s_street")'])
# Постройки ставят себя сами по Layout (scripts/world/layout.gd) — позиции здесь не важны.
node("House","Node3D",".",['script = ExtResource("s_house")'])
node("LiquorStore","Node3D",".",['script = ExtResource("s_liquor")'])
node("Casino","Node3D",".",['script = ExtResource("s_casino")'])
node("Thimbles","Node3D",".",['script = ExtResource("s_small")','kind = "thimbles"'])
node("Gosha","CharacterBody3D","Thimbles",['position = Vector3(0, 0.05, 0.2)',f'rotation = Vector3(0, {PI}, 0)','collision_layer = 8','collision_mask = 1','script = ExtResource("s_thimble")'])
node("Shape","CollisionShape3D","Thimbles/Gosha",['position = Vector3(0, 0.95, 0)','shape = SubResource("NpcShape")'])
node("Sync","MultiplayerSynchronizer","Thimbles/Gosha",['replication_config = SubResource("GoshaRepl")'])
# Фандомат и подработка — часть магазина (координаты магазина)
node("Fandomat","Node3D","Shop",['position = Vector3(6.4, 0, 6.3)','script = ExtResource("s_small")','kind = "fandomat"'])
node("LoaderJob","Node3D","Shop",['position = Vector3(12, 0, -1)','script = ExtResource("s_loader")'])
hides=[("dumpster",'anchor = "shop"','offset = Vector3(-11.3, 0, 1.5)'),("outhouse",'anchor = "house"','offset = Vector3(7.0, 0, 0.3)')]
for phi,off in [(-130,10),(-92,16),(-40,10),(48,9),(85,10),(-35,-7),(40,-8),(150,-8)]:
    hides.append(("bush",f'ring_phi = {phi}.0',f'ring_off = {off}.0'))
for i,(k,a1,a2) in enumerate(hides):
    node(f"Hide{i}_{k}","Node3D",".",['script = ExtResource("s_hiding")',f'kind = "{k}"',a1,a2])
node("Moonshine","Node3D","House",['position = Vector3(3.4, 0, 1.9)','rotation = Vector3(0, -1.5708, 0)','script = ExtResource("s_moon")'])
node("Sync","MultiplayerSynchronizer","House/Moonshine",['replication_config = SubResource("MoonRepl")'])
node("Garage","Node3D",".",['script = ExtResource("s_small")','kind = "garage"'])
node("Upgrades","Node3D","House",['script = ExtResource("s_house_up")'])
node("Sync","MultiplayerSynchronizer","House/Upgrades",['replication_config = SubResource("HouseRepl")'])
node("PoliceStation","Node3D",".",['script = ExtResource("s_police_st")'])
node("Police","CharacterBody3D",".",['script = ExtResource("s_police")'])
node("Sync","MultiplayerSynchronizer","Police",['replication_config = SubResource("PoliceRepl")'])
node("Babka","Node3D",".",['script = ExtResource("s_babka")'])
# Транспорт: лодки у пирса, велосипеды у дома и магазина, «Нива» под навесом
vehicles=[("Boat0","boat",['position = Vector3(2.5, 0, -12.0)'],'rent_price = 150'),
          ("Boat1","boat",['position = Vector3(-2.5, 0, -12.5)'],'rent_price = 150'),
          ("Bike0","bike",['home_spot = "house"','home_offset = Vector3(-6.0, 0, 3.0)'],'rent_price = 0'),
          ("Bike1","bike",['home_spot = "shop"','home_offset = Vector3(-4.5, 0, 7.2)','home_yaw = 1.5708'],'rent_price = 0'),
          ("Niva","niva",['home_spot = "garage"','home_offset = Vector3(0, 0, 0.3)','home_yaw = 3.14159'],'rent_price = 300')]
for nm,k,pos,rent in vehicles:
    node(nm,"CharacterBody3D",".",['script = ExtResource("s_vehicle")',f'kind = "{k}"',rent]+pos)
    node("Sync","MultiplayerSynchronizer",nm,['replication_config = SubResource("VehRepl")'])
node("Farm","Node3D",".",['script = ExtResource("s_farm")'])
node("Cow","CharacterBody3D",".",['script = ExtResource("s_cow")'])
node("Sync","MultiplayerSynchronizer","Cow",['replication_config = SubResource("CowRepl")'])
node("Club","Node3D",".",['script = ExtResource("s_club")'])
node("Sync","MultiplayerSynchronizer","Club",['replication_config = SubResource("ClubRepl")'])
for i,(nm,pos) in enumerate([("Кум Серёга","Vector3(-2.0, 0.05, 1.3)"),("Дядя Вова","Vector3(2.0, 0.05, 1.3)")]):
    node(f"Brawler{i}","CharacterBody3D","Club",['script = ExtResource("s_brawler")',f'position = {pos}',f'guest_name = "{nm}"',f'skin_id = {i}'])
    node("Sync","MultiplayerSynchronizer",f"Club/Brawler{i}",['replication_config = SubResource("BrawlRepl")'])
node("RepairJob","Node3D",".",['script = ExtResource("s_repair")'])
node("Nets","Node3D",".",['script = ExtResource("s_nets")'])
node("Inspector","Node3D",".",['script = ExtResource("s_inspector")'])
node("Sync","MultiplayerSynchronizer","Inspector",['replication_config = SubResource("InspRepl")'])
node("TsarSighting","Node3D",".",['script = ExtResource("s_tsar")'])
node("Grass","Node3D",".",['script = ExtResource("s_grass")'])
node("Decor","Node3D",".",['script = ExtResource("s_decor")'])
node("Bottles","Node3D",".",['script = ExtResource("s_bottles")'])
node("Spawner","MultiplayerSpawner","Bottles",['spawn_path = NodePath("..")'])
node("Mess","Node3D",".",['script = ExtResource("s_mess")'])
node("Spawner","MultiplayerSpawner","Mess",['spawn_path = NodePath("..")'])
node("Players","Node3D",".")
node("PlayerSpawner","MultiplayerSpawner",".",['spawn_path = NodePath("../Players")'])
for n,s in [("HUD","hud"),("TraderUI","traderui"),("FishBookUI","bookui"),("InventoryUI","invui"),("CasinoUI","casinoui"),("StoreUI","storeui"),
        ("GiveUI","giveui"),("HouseUI","houseui"),("MapUI","mapui"),("DayUI","dayui"),("PauseMenu","pause"),("MainMenu","menu"),("SettingsUI","settingsui"),("BribeUI","bribeui"),("DisputeUI","disputeui"),("RepairUI","repairui")]:
    node(n,"CanvasLayer",".",[f'script = ExtResource("s_{s}")'])
open("/home/claude/game-fish/scenes/world.tscn","w").write("\n".join(out))
print(len(items),"shop items")
