# Заметки для Claude

Кооперативная рыбалка «Клёвое место», Godot 4.7, GDScript, low-poly. Общение с автором — по-русски.
Суть игры: все пьют и пробуют ловить рыбу.

## Правило
После каждой доработки обновлять `CHANGELOG.md` (что сделано) и `DESIGN.md` (решения, числа, планы),
а также копии в проекте claude.ai «game».

## Архитектура
- Автозагрузки (порядок важен): Events, Controls, GameData, Saves, Inventory, Icons, Sfx, Settings, Net.
- Арт: `scripts/art/` — Art (кеш материалов), ItemModels (модели предметов), FishMesh (рыбы),
  CharacterModel (люди + анимация поз). Текстуры, лица, этикетки — PNG в `art/`, генерятся
  Python-скриптами (PIL); `Icons` рендерит иконки из моделей в SubViewport.
- Мир: `Terrain` (одна функция height(x,z): озеро, залив, остров, ровные площадки; HeightMapShape),
  `water.gd` (шейдер), `Reeds` (зоны зарослей, in_zone), `decor.gd`. Вода = height < WATER_Y.
- Инвентарь — 27 ячеек {kind,id,count,cond}; 0-8 — панель, выбранная = в руках. Садок отдельно.
  from_dict умеет старый формат v0.2.
- Сеть: ENet, хост = сервер. Регистрация: клиент шлёт `Net.register(profile_id, name)`,
  хост отвечает `apply_player(data)` и спавнит игрока (`player_registered`).
  Клиенты каждые 4 с шлют снимок (`store_player`), хост пишет мир каждые 45 с и при выходе игроков.
- `NetUtil.call_server / call_peer / call_all / sender` — единый способ RPC (у хоста — прямой вызов).
- Сохранения: `user://worlds/<файл>.json` у хоста: name, players{profile_id: {name, inventory, pos, rot}},
  trader{drunk, mood, loyalty{profile_id}}, bottles[[x,y,z,kind]]. Объекты пишут свою часть в `Saves.before_save`.
- Профиль: `user://profile.cfg` (id, имя, help_hidden). Несколько копий на одном ПК берут profile_N
  автоматически (lock-файлы) или по аргументу `--profile=N`.
- Случайные броски рыбы — на сервере (`FishingController.request_bite`), туда передаётся опьянение.
- Скрытая механика (НЕ писать в игре): опьянение повышает шанс редкой рыбы, вес и скорость клёва
  (`GameData.DRUNK_RARITY_BONUS`, roll_weight, roll_bite_delay).
- Инвентарь локальный (`Inventory`), сохраняется у хоста. Лояльность торговца хранит хост и присылает (`set_my_loyalty`).
- Магазин: `ShopController` следит за выходом с неоплаченной корзиной, `Guard` (серверный NPC, состояния
  WATCH/PHONE/DOZE/DISTRACTED/SUSPICIOUS/CHASE/RETURN, обход здания через углы).
- Торговец `Trader`: drunk/mood синхронизируются, торг считается у клиента (offer_factor/accept_factor).
- Бутылки: `Bottles` (MultiplayerSpawner), физика на хосте, у клиентов freeze.
- Взаимодействие: луч из глаз по слою 5 (Interactable, Area3D). `delegate_interactable.gd` передаёт родителю.
- UI собирается кодом (scripts/ui), стиль — `UiKit`. `Events.ui_open` блокирует управление.
- Слои физики: 1 земля/постройки, 4 игроки/NPC, 5 interact, 6 бутылки (2 и 3 свободны).
- world.tscn генерируется скриптом (держать в синхроне при правках руками в редакторе).
- Магазин называется «Шестёрочка» (пародия на торговую марку).
- v0.4: постройки посёлка — скрипты в `scripts/world/places/` (дом, «Бухло & Табак», казино, улица, укрытия,
  подработка, будка/фандомат), строятся из кода через `Build` (block/room/window/sign/text/lamp/talk_area/person).
  `talk_area` = `proxy_interactable.gd` с полем target. Модели людей смотрят в −Z.
- `DayCycle` (группа day_cycle): время/свет/небо, сон всем лобби (AWAKE → CHOOSING → SUMMARY), титулы дня.
  Синхронизация minutes/day/phase — узел DayCycle/Sync. Итоги собираются с клиентов (request_report).
- `Combat` (группа combat): удар → srv_hit на хосте → take_melee игроку или on_melee_hit у NPC.
- Казино: `CasinoDealer` (оценка вещи у клиента, бросок у хоста), Гоша = `ThimbleMan` (CharacterBody3D + Dealer).
- UI-окна на основе `ModalUi` (scripts/ui/modal_ui.gd); иконки — `ModalUi.item_icon` (подставляет готовую).
- v0.5: `Layout` (scripts/world/layout.gd) — кольцевая дорога (эллипс) и места построек SPOTS (угол, отступ, площадка).
  Постройки ставят себя в `_enter_tree()` по `Layout.xform(...)`; рельеф ровняется `Layout.flat_factor`,
  деревья/трава обходят `Layout.is_busy`. Фандомат и подработка — дети узла Shop. Спавн — `Layout.spawn()`.
- `Sfx` (автозагрузка): play(name, pos), loop(name, on), фон (птицы/сверчки/вода/музыка казино).
  WAV генерирует `tools/gen_sfx.py` в art/sfx. Звуки действий игроков — по смене синхронизированной позы.
- Двери — `swing_door.gd` (Build.door), открываются, когда рядом игрок/NPC.
- Рыбалка: ложные поклёвки (nibble), окно подсечки, рывки dash_dir (A/D против), «свеча» jump_time.
- Экспорт: `export_presets.cfg` (Windows Desktop, pck внутри exe). В облаке шаблоны в
  ~/.local/share/godot/export_templates/4.7.1.stable. exe отдаётся zip-частями + SOBRAT_EXE.bat.
- v0.6: `Vehicle` (scripts/world/vehicle.gd, CharacterBody3D) — лодка/велик/«Нива»: едет на хосте, водитель шлёт
  send_input 20 раз/с; места — occupants (Sync), игрок садится enter_vehicle/exit_vehicle и сам ставит себя на seat_transform.
- `Weather` (группа weather): состояние с хоста (Sync), apply(dc) вызывается из DayCycle после света;
  `Weather.update_conditions()` перед броском рыбы пишет `GameData.conditions` (ночь, крупная рыба, скорость клёва).
- `Tournament` (группа tournament) — соревнование 17:00–18:30, клиенты шлют report_catch.
- Самогонный аппарат — House/Moonshine (stage/left в Sync, сохраняется). Предметы kind "misc" (сахар, дрожжи), "tool" (фонарик).
- Тост — player.propose_toast → toast_offer (всем) → кто выпил в окне, тот _toast_bonus. Белочка — scripts/player/belochka.gd (только у себя).
- Озеро растягивается `Terrain.LAKE_SCALE` (lake_distance нормирует координаты), мир HALF = 100.
- v0.7: `Police` (scripts/world/npc/police.gd) — серверный NPC: report(peer, причина, strict), witness(peer, …, где) из Combat,
  охранник при краже зовёт report. Погоня по кольцу (`_route_to`). Арест → PoliceStation.jail → player.go_to_jail.
  Бабка (npc/babka.gd) — магазин через store_ui (store_title/seller_name), донос police.report.
  Улучшения дома — House/Upgrades (бит-маска upgrades в Sync; холодильник на хосте, UI — house_ui.gd).
- У NPC внутри повёрнутых построек поворачивать `global_rotation` (иначе ходят задом).
- Транспорту нужна своя talk_area больше корпуса — иначе луч взаимодействия упирается в коллизию.
- v0.8: мир X −110…110, Z −215…100 (`Terrain.X0..Z1`, коллизия смещена). Вода = ближнее озеро + протока (`RIVER`) +
  Дальний плёс (`FAR_C`), `Terrain.is_far`, мост `Terrain.on_bridge` (насыпь в height, настил — street.gd `_bridge_piece`).
  Транспорт «заезжает» на ступеньки < 0.35 м (vehicle.gd). Зоны рыбы: "far_" + open/deep/pit, Царь-сом — habitat PIT.
- Сети — узел Nets (список на хосте, клиентам show_nets), рыбнадзор — Inspector (Node3D, маршрут по воде из `_loop`, Sync).
- Взятка: Police.S.ESCORT → player.bribe_offer → BribeUI → Police.srv_bribe → bribe_result; jail(peer, reason, mult).
- Споры — в player.gd (dispute_offer/accepted/over, клиент↔клиент через rpc_id), окно DisputeUI. Похмелье — player.hangover
  (CanvasLayer с шейдером экрана), ставится в DayCycle.wake_up. Рассол — misc &"brine".
- Клуб (places/club.gd, class Club): расписание на хосте по DayCycle, kind/stage в Sync, драчуны npc/brawler.gd.
  Ферма (places/farm.gd, class Farm) + корова npc/cow.gd; ремонт — places/repair_job.gd + ui/repair_ui.gd (локально).
  Переноска: player.carry_kind ("box"/"sack") в Sync.
- `Settings` (автозагрузка): user://settings.cfg, качество/FOV/трава/шины/клавиши; `Controls.help()` берёт клавиши из InputMap.
  Шины звука: Effects, Ambient, Music, Voices (создаёт Sfx). `Sfx.babble(pos, voice, len)` — «симлиш»;
  реплики «Имя: «…»» в Events.notify бормочут сами; окна NPC — ui/speech_watch.gd.
- Build: gable_roof, plinth, corners, nalichnik (наличники), у окон отлив.
- gen_sfx.py при перезапуске пишет те же сэмплы, но байты WAV могут отличаться — перед отправкой сравнивать по данным.
- v0.8.1: `MeshBaker.bake(root)` (scripts/art/mesh_baker.gd) — вызывается из World._bake_static для списка BAKE.
  Не склеивает узлы со скриптом (кроме meta "bake_ok"), с meta "no_bake", CharacterModel, невидимые, в группах.
  Если что-то в постройке потом двигается/прячется — дать ему скрипт или set_meta("no_bake", true)!
- Vehicle: вид (`visual`, top_level) и seat_transform идут по сглаженному `_vis_xf` (process_priority −10);
  качка — `_rock`, не rotation у visual. Игрок в транспорте вызывает _follow_vehicle и в _process.
  Камера пешком сглаживается сдвигом головы (`_smooth_camera`, `_pp_prev`).
- Речь: `Sfx.say(pos, voice, text)` — TTS (project.godot audio/general/text_to_speech=true, русский голос системы),
  иначе babble; `Settings.voice_mode` 0/1/2. Реплики при подходе — `Chatter.attach(npc, voice, lines, высота, радиус)`.
- В главном меню мир стоит в сцене: всё, что шумит/ходит, проверяет `Net.is_online()` (погода, рыбнадзор, корова, участковый).
- В шейдерах с depth_texture учитывать CURRENT_RENDERER (в Compatibility ndc.z = d·2−1).
- Тесты: тестовая копия проекта с автозагрузкой TestRunner (одиночный сценарий, кооп из двух копий,
  скриншоты через xvfb + opengl3). В headless нет захвата мыши — в копии убирается проверка в fishing.gd.
- Файлы `.uid` и `.import` на ПК автора не перезаписывать (их делает его Godot).

## Планы
Костёр и жарка рыбы, квесты Толи, трофейная стена, зимняя рыбалка, баня, караоке, Steam.
