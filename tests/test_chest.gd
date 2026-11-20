extends SceneTree
## Testes do baú: construir, abrir, guardar, pegar, limites, save e remoção.
##
## Uso: godot --headless --path . --script res://tests/test_chest.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_chest"
const BASE := Vector3(-30, 0, 2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do baú ==")
	_wipe_dir()
	await _test_chest()
	await _test_save()
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


func _build_chest(world: Node) -> StorageChest:
	var player := world.get_node("Player") as CharacterBody3D
	var inv := player.get_node("Inventory") as Inventory
	player.global_position = BASE + Vector3(0, 0.1, 2.0)
	await _wait(2)
	inv.add_all({&"wood": 30, &"fiber": 10, &"stone": 4})
	var controller := world.get_node("PlacementController") as PlacementController
	var index := -1
	for i in controller.catalog.pieces.size():
		if controller.catalog.pieces[i].id == &"building_storage_chest":
			index = i
	_check(controller.catalog.pieces[index].required_knowledge == &"knowledge_storage", "Baú pede o conhecimento de armazenamento")
	(world.get_node("Progression/LevelManager") as LevelManager).sync_to_xp(100)
	controller.enter()
	controller.select(index)
	controller.update_preview(BASE + Vector3.UP * 12.0, Vector3.DOWN)
	var placed := controller.confirm()
	await _wait(2)
	controller.exit()
	_check(placed, "Baú construído no nível 2", controller.last_reason)
	for piece in (world.get_node("BuildingManager") as BuildingManager).get_pieces():
		if piece is StorageChest:
			return piece
	return null


func _test_chest() -> void:
	print("-- Baú --")
	var world := await _new_world()
	var player := world.get_node("Player") as CharacterBody3D
	var inv := player.get_node("Inventory") as Inventory
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var menu := world.get_node("ChestMenu") as ChestMenu
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var chest := await _build_chest(world)
	_check(chest != null and chest.storage.capacity == 20, "Baú com 20 espaços")
	inv.load_counts({&"wood": 12, &"stone": 8, &"flint": 3, &"stone_axe": 1, &"bandage": 2})
	player.global_position = chest.global_position + Vector3(0, 0.1, 1.4)
	await _wait(3)
	detector.refresh_focus()
	_check(detector.get_focused() == chest and chest.get_interaction_prompt().contains("vazio"), "Aviso '[E] Abrir baú (vazio)'")
	detector.try_interact()
	await _wait(2)
	_check(menu.is_open and menu.chest == chest and chest.is_open, "[E] abre o painel e a tampa")
	_check(menu.get_player_card_count() == 5 and menu.get_chest_card_count() == 0, "Mostra a mochila e o baú vazio")

	_check(menu.store(&"wood") == 12 and inv.count(&"wood") == 0 and chest.storage.count(&"wood") == 12, "Clique guarda o monte inteiro")
	_check(menu.take(&"wood", 1) == 1 and inv.count(&"wood") == 1 and chest.storage.count(&"wood") == 11, "Botão direito pega só 1")
	await _wait(1)
	_check(menu.get_chest_card_count() == 1, "Painel atualiza sozinho")

	var stored := menu.store_materials()
	_check(stored == 1 + 8 + 3 and inv.has_item(&"stone_axe") and inv.has_item(&"bandage"), "'Guardar materiais' guarda tudo, menos o que está na hotbar", str(stored))
	_check(chest.storage.count(&"wood") == 12 and chest.storage.count(&"stone") == 8 and chest.storage.count(&"flint") == 3, "Nada some nem duplica")

	equipment.select_slot(equipment.slot_of(&"stone_axe"))
	menu.store(&"stone_axe")
	_check(equipment.held_item == &"improvised_club" and equipment.slot_of(&"stone_axe") < 0, "Guardar a ferramenta da mão volta para a clava")
	_check(chest.blocks_removal(), "Baú com coisas dentro não pode ser removido")
	var r := (world.get_node("BuildingManager") as BuildingManager).remove(chest, inv)
	_check(not r["ok"] and is_instance_valid(chest), "Remoção recusada com aviso", r["message"])

	inv.capacity = 3
	var taken := menu.take_all()
	_check(inv.used_slots() <= 3 and taken > 0 and chest.storage.get_all().size() > 0, "Mochila cheia: pega o que couber, o resto fica")
	inv.capacity = 25
	menu.take_all()
	_check(chest.storage.get_all().is_empty() and inv.count(&"wood") == 12 and inv.has_item(&"stone_axe"), "'Pegar tudo' esvazia o baú")
	_check(not chest.blocks_removal(), "Vazio: pode remover")

	for i in 25:
		inv.add_item(StringName(["wood", "stone", "fiber"][i % 3]), 1)
	chest.storage.capacity = 1
	chest.storage.load_counts({&"fiber": 50})
	_check(menu.store(&"wood") == 0, "Baú cheio: nada é guardado")
	chest.storage.capacity = 20
	chest.storage.load_counts({})

	player.global_position = chest.global_position + Vector3(0, 0.1, 6.0)
	await _wait(3)
	_check(not menu.is_open and not chest.is_open, "Afastar-se fecha o painel e a tampa")
	await _free_world(world)


func _test_save() -> void:
	print("-- Save do baú --")
	var world := await _new_world()
	var chest := await _build_chest(world)
	chest.storage.load_counts({&"iron_ingot": 5, &"wood": 40})
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com o baú cheio")
	await _free_world(world)
	var again := await _new_world()
	_check(await (again.get_node("SaveManager") as SaveManager).load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	var restored: StorageChest = null
	for piece in (again.get_node("BuildingManager") as BuildingManager).get_pieces():
		if piece is StorageChest:
			restored = piece
	_check(restored != null and restored.storage.count(&"iron_ingot") == 5 and restored.storage.count(&"wood") == 40, "Conteúdo do baú restaurado")
	await _free_world(again)
	_wipe_dir()
