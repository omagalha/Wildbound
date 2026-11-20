extends SceneTree
## Testes do ferro: veios, fornalha, lingotes, ferramentas e espada de ferro.
##
## Uso: godot --headless --path . --script res://tests/test_iron.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_iron"
const BASE := Vector3(-30, 0, 2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do ferro ==")
	_wipe_dir()
	await _test_veins()
	await _test_furnace()
	await _test_iron_tools()
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


func _face(player: CharacterBody3D, point: Vector3) -> void:
	var to := point - player.global_position
	(player.get_node("Visual") as Node3D).rotation.y = atan2(-to.x, -to.z)


func _place(world: Node, index: int, target: Vector3) -> BuildingPiece:
	var controller := world.get_node("PlacementController") as PlacementController
	if not controller.active:
		controller.enter()
	controller.select(index)
	controller.update_preview(target + Vector3.UP * 12.0, Vector3.DOWN)
	controller.confirm()
	await _wait(2)
	controller.exit()
	var pieces := (world.get_node("BuildingManager") as BuildingManager).get_pieces()
	return pieces[pieces.size() - 1]


func _build_furnace(world: Node) -> Furnace:
	var player := world.get_node("Player") as CharacterBody3D
	var inv := player.get_node("Inventory") as Inventory
	(world.get_node("Progression/Experience") as ExperienceComponent).restore({"total_xp": 700})
	(world.get_node("Progression/LevelManager") as LevelManager).sync_to_xp(700)
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	await _wait(2)
	inv.add_all({&"wood": 20, &"stone": 20, &"flint": 4, &"fiber": 10})
	await _place(world, 0, BASE)  # fundação embaixo
	var controller := world.get_node("PlacementController") as PlacementController
	var index := -1
	for i in controller.catalog.pieces.size():
		if controller.catalog.pieces[i].id == &"building_furnace":
			index = i
	return await _place(world, index, BASE) as Furnace


# ---------- veios ----------

func _test_veins() -> void:
	print("-- Veios de ferro --")
	var world := await _new_world()
	var inv := (world.get_node("Player/Inventory") as Inventory)
	var player := world.get_node("Player") as CharacterBody3D
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var weapon := player.get_node("Visual/Weapon") as WeaponController
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var veins := []
	for node in (world.get_node("ResourceField") as ResourceScatter).spawned:
		if String(node.name).ends_with("_iron"):
			veins.append(node)
	_check(veins.size() == 10, "10 veios de ferro no mapa", str(veins.size()))
	var far := true
	for v in veins:
		if Vector2(v.global_position.x, v.global_position.z).length() < 90.0:
			far = false
	_check(far, "Veios só longe do início (exploração)")
	var vein := veins[0] as ResourceNode
	vein.yield_multiplier = 1.0
	var r := vein.interact(detector)
	_check(not r["ok"] and inv.count(&"iron_ore") == 0, "À mão: nada", r["message"])
	inv.add_all({&"stone_pickaxe": 1, &"flint_pickaxe": 1})
	equipment.select_slot(equipment.slot_of(&"stone_pickaxe"))
	player.global_position = vein.global_position + Vector3(0, 0.1, 1.5)
	_face(player, vein.global_position)
	await _wait(3)
	r = weapon.tool_strike()
	_check(not r.get("ok", true) and String(r.get("message", "")).contains("fraca demais") and inv.count(&"iron_ore") == 0, "Picareta de pedra: 'fraca demais'", r.get("message", ""))
	equipment.select_slot(equipment.slot_of(&"flint_pickaxe"))
	r = weapon.tool_strike()
	_check(r.get("ok", false) and inv.count(&"iron_ore") == vein.amount_per_harvest + 4, "Picareta de sílex: +6 minério (2 + 4)", str(inv.count(&"iron_ore")))
	await _free_world(world)


# ---------- fornalha ----------

func _test_furnace() -> void:
	print("-- Fornalha --")
	var world := await _new_world()
	var inv := (world.get_node("Player/Inventory") as Inventory)
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var manager := world.get_node("BuildingManager") as BuildingManager
	var furnace := await _build_furnace(world)
	_check(furnace != null, "Fornalha construída (nível 4)")
	_check(not furnace.is_burning() and furnace.get_interaction_prompt_for(detector).contains("vazia"), "Começa vazia e apagada")
	var r := furnace.interact(detector)
	_check(not r["ok"], "Sem minério: explica o que falta", r["message"])
	inv.load_counts({&"iron_ore": 7, &"wood": 2})
	r = furnace.interact(detector)
	_check(r["ok"] and furnace.ore == 6 and furnace.fuel == 2 and inv.count(&"iron_ore") == 1 and inv.count(&"wood") == 0, "Coloca minério em pares e só a lenha que dá", "%d/%d" % [furnace.ore, furnace.fuel])
	_check(furnace.is_burning() and (furnace.get_node("FearLight") as Node3D).visible and (furnace.get_node("Mouth") as Node3D).visible, "Queimando: fogo aceso e espanta lobos")
	furnace.tick(furnace.smelt_time + 0.01)
	_check(furnace.ingots == 1 and furnace.ore == 4 and furnace.fuel == 1, "1 lingote: 2 minério + 1 lenha")
	furnace.tick(furnace.smelt_time + 0.01)
	_check(furnace.ingots == 2 and furnace.ore == 2 and furnace.fuel == 0 and not furnace.is_burning(), "Sem lenha: para (sobra minério)")
	_check(not (furnace.get_node("FearLight") as Node3D).visible, "Apagada: não espanta mais")
	r = manager.remove(furnace, inv)
	_check(not r["ok"] and is_instance_valid(furnace), "Com coisas dentro, não pode remover")

	# Save: conteúdo preservado
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com a fornalha cheia")
	await _free_world(world)
	var again := await _new_world()
	var save2 := again.get_node("SaveManager") as SaveManager
	_check(await save2.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	var restored: Furnace = null
	for piece in (again.get_node("BuildingManager") as BuildingManager).get_pieces():
		if piece is Furnace:
			restored = piece
	_check(restored != null and restored.ingots == 2 and restored.ore == 2, "Fornalha volta com 2 lingotes e 2 minérios")
	var inv2 := (again.get_node("Player/Inventory") as Inventory)
	var detector2 := again.get_node("Player/InteractionDetector") as InteractionDetector
	_check(restored.get_interaction_prompt_for(detector2).contains("Pegar 2 lingotes"), "Aviso: pegar lingotes", restored.get_interaction_prompt_for(detector2))
	r = restored.interact(detector2)
	_check(r["ok"] and inv2.count(&"iron_ingot") == 2 and restored.ingots == 0, "[E] recolhe os lingotes")
	await _free_world(again)
	_wipe_dir()


# ---------- ferramentas de ferro ----------

func _test_iron_tools() -> void:
	print("-- Ferramentas de ferro --")
	var world := await _new_world()
	var inv := (world.get_node("Player/Inventory") as Inventory)
	var crafting := world.get_node("CraftingManager") as CraftingManager
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var weapon := world.get_node("Player/Visual/Weapon") as WeaponController
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var furnace := await _build_furnace(world)
	inv.add_all({&"iron_ingot": 10, &"wood": 5, &"fiber": 2})
	var player := world.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(60, 0.1, 60)
	var sword := crafting.get_recipe(&"recipe_iron_sword")
	_check(crafting.status(sword) == CraftingManager.NEEDS_STATION, "Longe da fornalha: não forja")
	player.global_position = furnace.global_position + Vector3(0, 0.1, 2.0)
	_check(crafting.status(sword) == CraftingManager.READY, "Perto da fornalha (nível 5): forja")
	_check(crafting.craft(sword)["ok"] and crafting.craft(crafting.get_recipe(&"recipe_iron_axe"))["ok"], "Forja espada e machado de ferro")
	equipment.select_slot(equipment.slot_of(&"iron_sword"))
	_check(weapon.definition.id == &"iron_sword" and weapon.definition.damage >= 30.0, "Espada na mão: 30 de dano")
	var blade := weapon.get_node_or_null("Club/IronSword") as Node3D
	_check(blade != null and blade.visible, "Visual da espada montado")
	equipment.select_slot(equipment.slot_of(&"iron_axe"))
	var tree := (world.get_node("TestWorld/Forest") as ForestGenerator).tree_bodies[4] as ForestTree
	var wood := inv.count(&"wood")
	var r := tree.tool_strike(detector, weapon.definition)
	_check(r.get("felled", false) and inv.count(&"wood") == wood + 9, "Machado de ferro: 1 golpe e +9 madeira", str(inv.count(&"wood") - wood))
	_check(inv.catalog.has_item(&"iron_ore") and inv.catalog.has_item(&"iron_ingot"), "Minério e lingote no catálogo")
	await _free_world(world)
