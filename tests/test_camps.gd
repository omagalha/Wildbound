extends SceneTree
## Testes dos acampamentos abandonados: descoberta, baú com saque e save.
##
## Uso: godot --headless --path . --script res://tests/test_camps.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_camps"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes dos acampamentos ==")
	_wipe_dir()
	await _test_camps()
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


func _test_camps() -> void:
	var world := await _new_world()
	var camps := world.get_node("Camps").get_children()
	_check(camps.size() == 5, "5 acampamentos no mapa")
	var camp := camps[0] as AbandonedCamp
	_check(camp.chest != null and not camp.chest.storage.get_all().is_empty(), "Cada um tem um baú com saque", str(camp.chest.storage.get_all()))
	_check(AbandonedCamp.roll_loot(11) == AbandonedCamp.roll_loot(11) and AbandonedCamp.roll_loot(11) != AbandonedCamp.roll_loot(12), "Saque fixo por acampamento e diferente entre eles")
	var manager := world.get_node("BuildingManager") as BuildingManager
	var inv := world.get_node("Player/Inventory") as Inventory
	_check(not manager.remove(camp.chest, inv)["ok"] and is_instance_valid(camp.chest), "Baú do acampamento não pode ser desmontado")

	var player := world.get_node("Player") as CharacterBody3D
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var xp := experience.total_xp
	player.global_position = camp.global_position + Vector3(0, 0.1, 6)
	await _wait(40)
	_check(camp.is_discovered and experience.total_xp == xp + experience.rules.discovery_xp, "Chegar perto: descoberta + XP")
	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	_check(hud.get_message().contains(camp.camp_name), "Aviso com o nome do acampamento", hud.get_message())

	var detector := player.get_node("InteractionDetector") as InteractionDetector
	player.global_position = camp.chest.global_position + Vector3(0, 0.1, 1.3)
	await _wait(3)
	detector.refresh_focus()
	_check(detector.get_focused() == camp.chest, "[E] mira o baú", str(detector.get_focused()))
	detector.try_interact()
	await _wait(2)
	var menu := world.get_node("ChestMenu") as ChestMenu
	_check(menu.is_open and menu.chest == camp.chest, "[E] abre o baú do acampamento")
	var loot := camp.chest.storage.get_all().duplicate()
	menu.take_all()
	var got_all := true
	for id in loot:
		if inv.count(id) != int(loot[id]):
			got_all = false
	_check(got_all and camp.chest.storage.get_all().is_empty(), "'Pegar tudo' traz o saque")
	menu.close()

	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com o baú esvaziado")
	await _free_world(world)
	var again := await _new_world()
	_check(await (again.get_node("SaveManager") as SaveManager).load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	var camp2 := again.get_node("Camps").get_child(0) as AbandonedCamp
	var other := again.get_node("Camps").get_child(1) as AbandonedCamp
	_check(camp2.chest.storage.get_all().is_empty(), "Baú esvaziado continua vazio (saque não renasce)")
	_check(camp2.is_discovered, "Descoberta preservada")
	_check(not other.chest.storage.get_all().is_empty() and not other.is_discovered, "Outros acampamentos intactos")
	await _free_world(again)
