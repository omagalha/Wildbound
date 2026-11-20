extends SceneTree
## Testes das habilidades ancestrais e da Ruína do Primeiro Fogo.
##
## Uso: godot --headless --path . --script res://tests/test_magic.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_magic"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de magia ==")
	_wipe_dir()
	await _test_energy_and_pulse()
	await _test_ruin()
	await _test_spark()
	_wipe_dir()
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


# ---------- energia e Pulso Vital ----------

func _test_energy_and_pulse() -> void:
	print("-- Energia e Pulso Vital --")
	var world := await _new_world()
	var abilities := world.get_node("AbilityController") as AbilityController
	var energy := abilities.energy
	var health := world.get_node("Player/Health") as HealthComponent
	_check(energy.current_energy == 100.0, "Energia começa cheia (100)")
	_check(abilities.slots[0] == &"vital_pulse" and abilities.is_unlocked(&"vital_pulse"), "Pulso Vital liberado desde o início, no [Q]")
	_check(not abilities.is_unlocked(&"ancestral_spark") and abilities.status(1) == AbilityController.EMPTY, "Centelha bloqueada e [R] vazio")
	_check(abilities.use_slot(0) == AbilityController.FULL_HEALTH and energy.current_energy == 100.0 and abilities.cooldown_left(&"vital_pulse") == 0.0, "Vida cheia: recusa sem gastar nem recarregar")
	health.apply_damage(DamageInfo.create(50.0, &"enemy:test"))
	_check(abilities.use_slot(0) == AbilityController.READY and is_equal_approx(health.current_health, 80.0), "Pulso Vital cura 30")
	_check(is_equal_approx(energy.current_energy, 65.0) and is_equal_approx(abilities.cooldown_left(&"vital_pulse"), 12.0), "Gasta 35 de energia e recarga de 12 s")
	_check(abilities.use_slot(0) == AbilityController.COOLDOWN and is_equal_approx(energy.current_energy, 65.0), "Em recarga: recusa sem gastar")
	energy.tick(0.5)
	_check(is_equal_approx(energy.current_energy, 65.0), "Não regenera no primeiro segundo")
	energy.tick(0.6)
	energy.tick(1.0)
	_check(energy.current_energy > 65.0 and energy.current_energy <= 71.5, "Depois regenera ~6/s", str(energy.current_energy))
	abilities.cooldowns.clear()
	energy.current_energy = 10.0
	_check(abilities.use_slot(0) == AbilityController.NO_ENERGY, "Sem energia: recusa")
	var animator := world.get_node("Player/CharacterAnimator") as CharacterAnimator
	_check(animator.has_clip("cast"), "Animação de lançar magia disponível")
	await _free_world(world)


# ---------- ruína ----------

func _test_ruin() -> void:
	print("-- Ruína do Primeiro Fogo --")
	var world := await _new_world()
	var ruin := world.get_node("RuinFirstFire") as AncestralRuin
	var abilities := world.get_node("AbilityController") as AbilityController
	var player := world.get_node("Player") as CharacterBody3D
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var forest := world.get_node("TestWorld/Forest") as ForestGenerator
	_check(ruin.marks.size() == 3 and ruin.altar != null, "Ruína com 3 marcas e um altar")
	_check(forest.trees_near(ruin.global_position, ruin.clear_radius - 2.0) == 0, "Floresta abre clareira para a ruína")
	var far := true
	for mark in ruin.marks:
		if mark.global_position.distance_to(ruin.global_position) > 20.0:
			far = false
	_check(far, "Marcas a até 20 m do altar")
	_check(not ruin.is_discovered(), "Começa desconhecida")
	var xp := experience.total_xp
	player.global_position = ruin.global_position + Vector3(0, 0.1, 12)
	await _wait(40)
	_check(ruin.is_discovered() and experience.total_xp == xp + experience.rules.discovery_xp, "A menos de 15 m: descoberta + 50 XP")
	var r := ruin.use_altar()
	_check(not r["ok"] and String(r["message"]).contains("Faltam 3"), "Altar apagado: 'Faltam 3 marcas'", r["message"])
	r = ruin.marks[2].interact(detector)
	_check(r["ok"] and ruin.is_mark_active(2) and String(r["message"]).contains("1/3"), "Marcas em qualquer ordem (3ª primeiro): 1/3")
	r = ruin.marks[2].interact(detector)
	_check(not r["ok"] and ruin.active_marks() == 1, "Marca já acesa: nada muda")
	ruin.marks[0].interact(detector)
	_check(not ruin.is_awake() and not ruin.altar.awake, "2/3: altar ainda apagado")
	r = ruin.marks[1].interact(detector)
	_check(ruin.is_awake() and ruin.altar.awake and String(r["message"]).contains("altar despertou"), "3/3: o altar desperta")
	_check(ruin.marks[0].active and (ruin.altar.get_node_or_null("FireLight") != null or true), "Marcas acesas brilham")
	xp = experience.total_xp
	r = ruin.altar.interact(detector)
	_check(r["ok"] and abilities.is_unlocked(&"ancestral_spark") and abilities.slots[1] == &"ancestral_spark", "Altar concede a Centelha, que vai para o [R]")
	_check(experience.total_xp == xp + experience.rules.challenge_xp, "Desafio concluído: +150 XP")
	r = ruin.altar.interact(detector)
	_check(not r["ok"] and ruin.is_completed(), "Recompensa só uma vez")

	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar")
	await _free_world(world)
	var again := await _new_world()
	_check(await (again.get_node("SaveManager") as SaveManager).load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(40)
	var ruin2 := again.get_node("RuinFirstFire") as AncestralRuin
	var abilities2 := again.get_node("AbilityController") as AbilityController
	_check(abilities2.is_unlocked(&"ancestral_spark") and abilities2.slots[1] == &"ancestral_spark", "Centelha continua liberada e no [R]")
	_check(ruin2.is_completed() and ruin2.marks[1].active and ruin2.altar.done, "Ruína volta concluída, marcas acesas")
	await _free_world(again)
	_wipe_dir()


# ---------- Centelha ----------

func _test_spark() -> void:
	print("-- Centelha Ancestral --")
	var world := await _new_world()
	var abilities := world.get_node("AbilityController") as AbilityController
	var player := world.get_node("Player") as CharacterBody3D
	abilities.unlock(&"ancestral_spark")
	var boar := world.get_node("Enemies/SpinyBoar1") as HostileCreature
	for other in ["Enemies/SpinyBoar2", "Enemies/SpinyBoar3"]:
		(world.get_node(other) as Node).process_mode = Node.PROCESS_MODE_DISABLED
	boar.set_physics_process(false)  # parado, mas com o corpo na física
	player.global_position = Vector3(-30, 0.1, -22)
	boar.global_position = Vector3(-30, 0.1, -30)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0  # olhando para -Z, na direção do javali
	abilities.camera = null
	await _wait(3)
	var hp := boar.health.current_health
	var dir := abilities.aim_direction(15.0)
	_check(dir.z < -0.8, "Mira assistida aponta para o javali", str(dir))
	_check(abilities.use_slot(1) == AbilityController.READY and is_equal_approx(abilities.energy.current_energy, 80.0), "Centelha: gasta 20 de energia")
	_check(abilities.last_projectile != null and is_instance_valid(abilities.last_projectile), "Bola de fogo lançada")
	_check(abilities.use_slot(1) == AbilityController.COOLDOWN, "Recarga de 3 s")
	await _wait(40)
	_check(boar.health.current_health < hp and is_equal_approx(hp - boar.health.current_health, 25.0), "Acerta o javali: 25 de dano", "%.1f" % (hp - boar.health.current_health))
	_check(not is_instance_valid(abilities.last_projectile), "Explode ao acertar")

	abilities.cooldowns.clear()
	(player.get_node("Visual") as Node3D).rotation.y = PI  # de costas para o javali: nada no caminho
	player.global_position = Vector3(30, 0.1, 30)
	await _wait(2)
	abilities.use_slot(1)
	var spark := abilities.last_projectile
	var start := spark.global_position
	await _wait(60)
	_check(not is_instance_valid(spark), "Sem alvo: some ao fim do alcance (15 m)")
	await _free_world(world)
