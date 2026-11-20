extends SceneTree
## Testes do perigo noturno: Lobos Sombrios, medo do fogo e amanhecer.
##
## Uso: godot --headless --path . --script res://tests/test_night.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_night"
const FIELD := Vector3(70, 0.1, 60)  # mata aberta, longe de zonas e ninhos

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes da noite ==")
	await _test_spawning()
	await _test_hunting_and_fire()
	await _test_dawn_and_death()
	print("== Resultado: %d passaram, %d falharam ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", name)
	else:
		_failed += 1
		print("  [FAIL] ", name, ("  -> " + detail) if detail != "" else "")


func _wait(frames: int = 2) -> void:
	for i in frames:
		await physics_frame


func _new_world() -> Node:
	var world := (load(MAIN_SCENE) as PackedScene).instantiate()
	var save := world.get_node("SaveManager") as SaveManager
	save.load_on_start = false
	save.autosave_interval = 0.0
	save.save_dir = TEST_DIR
	(world.get_node("DifficultyManager") as DifficultyManager).ask_on_new_world = false
	root.add_child(world)
	await _wait(3)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = FIELD
	# O relógio só anda pelo teste.
	(world.get_node("TestWorld/DayNight") as DayNightCycle).set_process(false)
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


func _set_hour(world: Node, hour: float) -> void:
	var cycle := world.get_node("TestWorld/DayNight") as DayNightCycle
	cycle.hour = hour
	cycle.apply_lighting()


func _tick(hunt: NightHunt, seconds: int) -> void:
	for i in seconds:
		hunt.tick(1.0)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- surgimento ----------

func _test_spawning() -> void:
	print("-- Matilhas --")
	var world := await _new_world()
	var hunt := world.get_node("NightHunt") as NightHunt
	hunt.set_physics_process(false)
	var player := world.get_node("Player") as CharacterBody3D
	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	var enemies_before := world.get_node("Enemies").get_child_count()

	_tick(hunt, 60)
	_check(hunt.alive_count() == 0, "De dia não aparece lobo")

	_set_hour(world, 21.0)
	hunt.tick(0.1)
	_check(hud.get_message().contains("noite"), "Aviso ao anoitecer", hud.get_message())
	_tick(hunt, 10)
	_check(hunt.alive_count() == 0, "Primeiros segundos da noite: ainda calmo")
	_tick(hunt, 12)
	_check(hunt.alive_count() == 2, "Matilha de 2 no Intermediário", str(hunt.alive_count()))
	var ok_distance := true
	var ok_zone := true
	for wolf in hunt.wolves():
		var d := _flat_distance(wolf.global_position, player.global_position)
		if d < hunt.spawn_min_distance - 2.5 or d > hunt.spawn_max_distance + 2.5:
			ok_distance = false
		if TerritoryZone.is_safe(world.get_tree(), wolf.global_position):
			ok_zone = false
	_check(ok_distance, "Surgem longe da vista (30–42 m)")
	_check(ok_zone, "Nunca dentro de zona segura")
	_check(world.get_node("Enemies").get_child_count() == enemies_before, "Lobos não contam no limite de hostis do mapa")

	_tick(hunt, 300)
	_check(hunt.alive_count() <= hunt.max_alive and hunt.alive_count() >= 3, "Novas matilhas, até o máximo de 4", str(hunt.alive_count()))

	var wolf := hunt.wolves()[0]
	_check(wolf.definition.fears_light and not wolf.definition.respawns, "Lobo teme o fogo e não renasce")
	hunt.dismiss_all()
	await _wait(1)
	(world.get_node("DifficultyManager") as DifficultyManager).apply((world.get_node("DifficultyManager") as DifficultyManager).get_preset(&"easy"))
	_check(hunt.spawn_pack() == 1, "Fácil: lobo solitário")
	(world.get_node("DifficultyManager") as DifficultyManager).apply((world.get_node("DifficultyManager") as DifficultyManager).get_preset(&"hard"))
	var hard_wolf := hunt.wolves()[0]
	hunt.dismiss_all()
	await _wait(1)
	hunt.spawn_pack()
	hard_wolf = hunt.wolves()[0]
	_check(hard_wolf.health.max_health > 35.0 and hunt.alive_count() == 3, "Difícil: matilha de 3 e lobos mais fortes")
	await _free_world(world)


# ---------- caçada e fogo ----------

func _test_hunting_and_fire() -> void:
	print("-- Caçada e fogo --")
	var world := await _new_world()
	var hunt := world.get_node("NightHunt") as NightHunt
	hunt.set_physics_process(false)
	var player := world.get_node("Player") as CharacterBody3D
	var inv := player.get_node("Inventory") as Inventory
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	_set_hour(world, 23.0)
	hunt.spawn_pack()
	var wolves := hunt.wolves()
	for w in wolves:
		w._grace_left = 0.0
	var wolf := wolves[0]
	wolf.global_position = player.global_position + Vector3(9, 0, 0)
	wolf.home = wolf.global_position
	wolves[1].global_position = player.global_position + Vector3(-60, 0, 0)
	wolves[1].home = wolves[1].global_position
	await _wait(10)
	_check(wolf.state != HostileCreature.State.IDLE, "No escuro, o lobo caça", wolf.state_name())

	var health := player.get_node("Health") as HealthComponent
	var hit := [false]
	wolf.attacked_player.connect(func(_d, _k): hit[0] = true)
	await _wait(150)
	_check(hit[0] and health.current_health < health.max_health, "Lobo morde/investe no jogador", str(health.current_health))

	inv.add_item(&"torch", 1)
	equipment.set_torch(true)
	_check(wolf.is_scared_by_light() and not wolf.player_huntable(), "Tocha acesa: o lobo não caça")
	await _wait(60)
	_check(wolf.state in [HostileCreature.State.RETURN, HostileCreature.State.IDLE], "Tocha acesa: o lobo recua", wolf.state_name())
	health.current_health = health.max_health
	var hp := health.current_health
	await _wait(90)
	_check(is_equal_approx(health.current_health, hp), "Com fogo, ninguém ataca")
	equipment.set_torch(false)
	_check(wolf.player_huntable(), "Tocha apagada: volta a ser presa")

	# Fogueira de verdade protege; a prévia do modo de construção, não.
	var controller := world.get_node("PlacementController") as PlacementController
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	experience.restore({"total_xp": 700})
	inv.add_all({&"wood": 20, &"stone": 10})
	controller.enter()
	controller.select(4)
	controller.update_preview(player.global_position + Vector3(2, 12, 0), Vector3.DOWN)
	await _wait(1)
	_check(not FireLight.is_point_lit(world.get_tree(), player.global_position), "Prévia da fogueira não espanta lobos")
	controller.select(0)
	controller.update_preview(player.global_position + Vector3(2, 12, 0), Vector3.DOWN)
	controller.confirm()
	await _wait(2)
	controller.select(4)
	controller.update_preview(player.global_position + Vector3(2, 12, 0), Vector3.DOWN)
	controller.confirm()
	await _wait(2)
	controller.exit()
	var fires := 0
	for piece in (world.get_node("BuildingManager") as BuildingManager).get_pieces():
		if piece.definition.id == &"building_campfire_primitive":
			fires += 1
	_check(fires == 1, "Fogueira construída ao lado")
	_check(FireLight.is_point_lit(world.get_tree(), player.global_position) and not wolf.player_huntable(), "Perto da fogueira, seguro")
	_check(not FireLight.is_point_lit(world.get_tree(), player.global_position + Vector3(20, 0, 0)), "Longe da fogueira, perigo")
	await _free_world(world)


# ---------- amanhecer e morte ----------

func _test_dawn_and_death() -> void:
	print("-- Amanhecer e morte --")
	var world := await _new_world()
	var hunt := world.get_node("NightHunt") as NightHunt
	hunt.set_physics_process(false)
	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	_set_hour(world, 22.0)
	hunt.tick(0.1)
	hunt.spawn_pack()
	var wolf := hunt.wolves()[0]
	wolf.receive_damage(DamageInfo.create(1000.0, &"player:test"))
	await _wait(2)
	_check(world.find_children("*", "LootDrop", true, false).size() == 1, "Lobo abatido deixa carne")
	_check(hunt.alive_count() == 1, "Morto não conta como vivo")
	await _wait(200)
	_check(not is_instance_valid(wolf), "Corpo some e não renasce")

	_set_hour(world, 7.0)
	hunt.tick(0.1)
	await _wait(1)
	_check(hunt.alive_count() == 0 and hunt.get_child_count() == 0, "Amanhecer: todos os lobos somem")
	_check(hud.get_message().contains("Amanheceu"), "Aviso do amanhecer", hud.get_message())
	_tick(hunt, 120)
	_check(hunt.alive_count() == 0, "De dia não voltam")
	await _free_world(world)
