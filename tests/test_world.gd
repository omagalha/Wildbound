extends SceneTree
## Testes do "Mundo vivo": floresta procedural, recursos espalhados, ciclo de dia e noite.
##
## Uso: godot --headless --path . --script res://tests/test_world.gd
## Grava numa pasta só de testes (user://test_saves_world), nunca no save do jogo.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_world"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do mundo ==")
	_wipe_dir()
	await _test_forest()
	await _test_scatter()
	await _test_day_night()
	await _test_time_save()
	_wipe_dir()
	print("== Resultado: %d passaram, %d falharam ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------- utilidades ----------

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


func _wipe_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


func _new_world() -> Node:
	var world := (load(MAIN_SCENE) as PackedScene).instantiate()
	var save := world.get_node("SaveManager") as SaveManager
	save.load_on_start = false
	save.autosave_interval = 0.0
	save.save_dir = TEST_DIR
	(world.get_node("DifficultyManager") as DifficultyManager).ask_on_new_world = false
	root.add_child(world)
	await _wait(3)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# ---------- floresta ----------

func _test_forest() -> void:
	print("-- Floresta procedural --")
	var world := await _new_world()
	var forest := world.get_node("TestWorld/Forest") as ForestGenerator
	_check(forest != null and forest.generated, "Floresta gerada ao entrar na cena")
	_check(forest.tree_bodies.size() >= 300, "Centenas de árvores com colisão", str(forest.tree_bodies.size()))
	_check(forest.trees_near(Vector3.ZERO, forest.keep_clear_radius) == 0, "Área inicial e de teste sem árvores novas")

	var near_resource := 0
	for node in world.find_children("*", "ResourceNode", true, false):
		near_resource += forest.trees_near((node as Node3D).global_position, 1.5)
	_check(near_resource == 0, "Nenhuma árvore em cima de uma fonte de recurso", str(near_resource))

	var safe := world.get_node("Zones/SafeStart") as TerritoryZone
	_check(forest.trees_near(safe.global_position, safe.radius - 1.0) == 0, "Zona segura continua aberta")
	var outside := 0
	for body in forest.tree_bodies:
		if absf(body.global_position.x) > forest.half_size + 0.1 or absf(body.global_position.z) > forest.half_size + 0.1:
			outside += 1
	_check(outside == 0, "Todas as árvores dentro das bordas do mapa")

	var visuals := world.get_node("TestWorld/Forest/Visuals")
	var kinds := {}
	for child in visuals.get_children():
		if child is MultiMeshInstance3D:
			kinds[String(child.name).get_slice("_", 0)] = true
	_check(kinds.has("pine") and kinds.has("oak") and kinds.has("grass") and kinds.has("flower") and kinds.has("rock"), "Pinheiros, frondosas, grama, flores e rochas", str(kinds.keys()))
	_check(visuals.get_node_or_null("Mountains") != null and visuals.get_node("Mountains").get_child_count() > 10, "Montanhas no horizonte")

	var first := []
	for body in forest.tree_bodies:
		first.append(body.global_position)
	await _free_world(world)

	var again := await _new_world()
	var forest2 := again.get_node("TestWorld/Forest") as ForestGenerator
	var same := forest2.tree_bodies.size() == first.size()
	if same:
		for i in first.size():
			if not forest2.tree_bodies[i].global_position.is_equal_approx(first[i]):
				same = false
				break
	_check(same, "Mesma semente gera exatamente a mesma floresta")

	var ground := again.get_node("TestWorld/Ground/CollisionShape3D") as CollisionShape3D
	_check((ground.shape as BoxShape3D).size.x >= 300.0, "Mapa com 300 × 300 m")
	await _free_world(again)


# ---------- recursos espalhados ----------

func _test_scatter() -> void:
	print("-- Recursos espalhados --")
	var world := await _new_world()
	var scatter := world.get_node("ResourceField") as ResourceScatter
	_check(scatter != null and scatter.spawned.size() >= 60, "Dezenas de fontes extras pela floresta", str(scatter.spawned.size()))
	var categories := {}
	var too_close := 0
	var outside := 0
	for node in scatter.spawned:
		categories[node.category] = true
		if _flat(node.global_position).length() < scatter.inner_radius - 5.0:
			too_close += 1
		if absf(node.global_position.x) > 148.0 or absf(node.global_position.z) > 148.0:
			outside += 1
	_check(categories.size() == 4, "Os quatro tipos aparecem (madeira, pedra, fibra, frutas)", str(categories.keys()))
	_check(too_close == 0, "Nada novo na área inicial")
	_check(outside == 0, "Tudo dentro das bordas")
	var first_name := String(scatter.spawned[0].name)
	var first_pos := scatter.spawned[0].global_position
	_check(world.get_node_or_null("ResourceField/Wilds/" + first_name) == scatter.spawned[0], "Caminho estável para o save", first_name)

	var difficulty := world.get_node("DifficultyManager") as DifficultyManager
	difficulty.apply(difficulty.get_preset(&"easy"))
	_check(is_equal_approx(scatter.spawned[0].yield_multiplier, 1.3), "Multiplicador de recursos do preset chega às fontes novas")

	# Coletar uma fonte nova e recarregar: o estado volta.
	var node := scatter.spawned[0]
	var player := world.get_node("Player") as CharacterBody3D
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	node.interact(detector)
	var left := node.harvests_left
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com as fontes novas")
	await _free_world(world)

	var again := await _new_world()
	var save2 := again.get_node("SaveManager") as SaveManager
	_check(await save2.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(4)
	var restored := again.get_node("ResourceField/Wilds/" + first_name) as ResourceNode
	_check(restored != null and restored.global_position.is_equal_approx(first_pos), "Mesma fonte, mesmo lugar")
	_check(restored != null and restored.harvests_left == left, "Coletas restantes preservadas", "%s vs %d" % [restored.harvests_left if restored else -1, left])
	await _free_world(again)
	_wipe_dir()


# ---------- dia e noite ----------

func _test_day_night() -> void:
	print("-- Dia e noite --")
	var world := await _new_world()
	var cycle := world.get_node("TestWorld/DayNight") as DayNightCycle
	var sun := world.get_node("TestWorld/Sun") as DirectionalLight3D
	_check(cycle != null and cycle.day == 1 and absf(cycle.hour - cycle.start_hour) < 0.1, "Começa no dia 1 às 8 h")
	_check(not cycle.is_night(), "8 h é dia")
	cycle.hour = 12.0
	cycle.apply_lighting()
	var noon_energy := sun.light_energy
	var noon_dir := -sun.global_transform.basis.z
	_check(noon_dir.y < -0.8, "Meio-dia: sol alto", str(noon_dir))
	_check(sun.shadow_enabled, "Sol continua com sombras")

	var nights := [0]
	var days := [0]
	cycle.night_started.connect(func(_d): nights[0] += 1)
	cycle.day_started.connect(func(_d): days[0] += 1)
	cycle.advance(cycle.day_length * (10.0 / 24.0))  # 12 h → 22 h
	_check(cycle.is_night() and nights[0] == 1, "Às 22 h é noite e o aviso sai uma vez")
	_check(sun.light_energy < noon_energy * 0.5, "Noite bem mais escura que o dia", "%.2f vs %.2f" % [sun.light_energy, noon_energy])
	_check((-sun.global_transform.basis.z).y < 0.0, "A luz da lua ainda vem de cima")
	cycle.advance(cycle.day_length * (10.0 / 24.0))  # 22 h → 8 h
	_check(cycle.day == 2 and days[0] == 1 and not cycle.is_night(), "Amanhece no dia 2", cycle.clock_text())
	_check(cycle.clock_text().begins_with("Dia 2 · 08:"), "Relógio legível", cycle.clock_text())

	var env := (world.get_node("TestWorld/WorldEnvironment") as WorldEnvironment).environment
	_check(env.fog_enabled, "Névoa ligada")
	await _free_world(world)


func _test_time_save() -> void:
	print("-- Save do horário --")
	var world := await _new_world()
	var cycle := world.get_node("TestWorld/DayNight") as DayNightCycle
	cycle.day = 4
	cycle.hour = 21.5
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar à noite do dia 4")
	await _free_world(world)

	var again := await _new_world()
	var cycle2 := again.get_node("TestWorld/DayNight") as DayNightCycle
	var save2 := again.get_node("SaveManager") as SaveManager
	_check(await save2.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(4)
	_check(cycle2.day == 4 and absf(cycle2.hour - 21.5) < 0.05 and cycle2.is_night(), "Dia e hora restaurados", cycle2.clock_text())
	cycle2.apply_save_data({"day": -3, "hour": 99.0})
	_check(cycle2.day == 1 and cycle2.hour < 24.0, "Valores absurdos são corrigidos")
	await _free_world(again)
	_wipe_dir()
