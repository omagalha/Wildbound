extends SceneTree
## Testes de fabricação, ferramentas, equipamento e carne de javali.
##
## Uso: godot --headless --path . --script res://tests/test_crafting.gd
## Grava numa pasta só de testes (user://test_saves_crafting), nunca no save do jogo.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_crafting"
const BASE := Vector3(-30, 0, 2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de fabricação ==")
	_wipe_dir()
	await _test_recipes()
	await _test_station()
	await _test_tools()
	await _test_forest_tree()
	await _test_equipment()
	await _test_boar_loot()
	await _test_menu()
	await _test_hotbar()
	await _test_marker()
	await _test_flint()
	await _test_save()
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


func _inv(world: Node) -> Inventory:
	return world.get_node("Player/Inventory") as Inventory


func _crafting(world: Node) -> CraftingManager:
	return world.get_node("CraftingManager") as CraftingManager


func _place(world: Node, index: int, target: Vector3) -> BuildingPiece:
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	if experience.total_xp < 700:
		experience.restore({"total_xp": 700})
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


# ---------- receitas ----------

func _test_recipes() -> void:
	print("-- Receitas --")
	var world := await _new_world()
	var crafting := _crafting(world)
	var inv := _inv(world)
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	_check(crafting.recipes.size() == 14, "Catorze receitas no menu", str(crafting.recipes.size()))

	var axe := crafting.get_recipe(&"recipe_stone_axe")
	_check(crafting.status(axe) == CraftingManager.MISSING, "Sem materiais: 'missing'")
	var r := crafting.craft(axe)
	_check(not r["ok"] and inv.get_all().is_empty(), "Recusa não mexe no inventário")

	inv.add_all({&"wood": 5, &"stone": 4, &"fiber": 6})
	_check(crafting.status(axe) == CraftingManager.READY, "Com materiais e nível 1: pronto")
	var xp_before := experience.total_xp
	r = crafting.craft(axe)
	_check(r["ok"] and inv.has_item(&"stone_axe"), "Fabrica o machado")
	_check(inv.count(&"wood") == 2 and inv.count(&"stone") == 2 and inv.count(&"fiber") == 4, "Consome exatamente os insumos")
	_check(experience.total_xp == xp_before + experience.rules.first_recipe_xp, "Primeira fabricação dá XP")
	_check(crafting.status(axe) == CraftingManager.ALREADY_HAVE, "Ferramenta única: não fabrica outra")

	var spear := crafting.get_recipe(&"recipe_stone_spear")
	inv.add_all({&"wood": 4, &"stone": 2, &"fiber": 3})
	_check(crafting.status(spear) == CraftingManager.LOCKED, "Lança bloqueada no nível 1")
	experience.restore({"total_xp": 100})
	var levels := world.get_node("Progression/LevelManager") as LevelManager
	levels.sync_to_xp(100)
	_check(crafting.status(spear) == CraftingManager.READY, "Nível 2 libera a lança")

	var bandage := crafting.get_recipe(&"recipe_bandage")
	inv.load_counts({&"fiber": 8})
	crafting.craft(bandage)
	xp_before = experience.total_xp
	crafting.craft(bandage)
	_check(inv.count(&"bandage") == 2 and inv.count(&"fiber") == 0, "Ataduras empilham")
	_check(experience.total_xp == xp_before, "XP só na primeira vez de cada receita")

	# Inventário cheio: só cabe se os insumos liberarem espaço.
	inv.capacity = 2
	inv.load_counts({&"fiber": 4, &"wild_berries": 5})
	_check(crafting.status(bandage) == CraftingManager.READY, "Insumo que esvazia um espaço abre lugar para o produto")
	inv.load_counts({&"wood": 2, &"fiber": 3})
	_check(crafting.status(crafting.get_recipe(&"recipe_torch")) == CraftingManager.NO_SPACE, "Sem espaço para o produto: 'no_space'")
	await _free_world(world)


func _test_station() -> void:
	print("-- Fogueira --")
	var world := await _new_world()
	var crafting := _crafting(world)
	var inv := _inv(world)
	var player := world.get_node("Player") as CharacterBody3D
	var meat := crafting.get_recipe(&"recipe_cooked_meat")
	inv.add_item(&"raw_meat", 2)
	player.global_position = BASE + Vector3(0, 0.1, 6)
	_check(crafting.status(meat) == CraftingManager.NEEDS_STATION, "Longe de fogueira: 'needs_station'")
	_check(crafting.reason_text(meat, CraftingManager.NEEDS_STATION).contains("fogueira"), "Aviso cita a fogueira")
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	await _wait(2)
	inv.add_all({&"wood": 20, &"stone": 10, &"fiber": 10})
	await _place(world, 0, BASE)  # fogueira vai sobre uma fundação
	var fire := await _place(world, 4, BASE)
	_check(fire != null and fire.definition.id == &"building_campfire_primitive", "Fogueira construída")
	player.global_position = fire.global_position + Vector3(0, 0.1, 2.0)
	_check(crafting.status(meat) == CraftingManager.READY, "Perto da fogueira: pronto")
	_check(crafting.craft(meat)["ok"] and inv.count(&"cooked_meat") == 1 and inv.count(&"raw_meat") == 1, "Assa uma carne")

	var item := inv.catalog.get_item(&"raw_meat")
	_check(not item.is_food(), "Carne crua não é comida")
	var hunger := player.get_node("Hunger") as HungerComponent
	hunger.set_hunger(30.0)
	var food := player.get_node("FoodConsumer") as FoodConsumer
	_check(food.try_eat() == FoodConsumer.REASON_OK and absf(hunger.current_hunger - 70.0) < 0.5, "Carne assada recupera 40 de fome", str(hunger.current_hunger))
	await _free_world(world)


# ---------- ferramentas ----------

func _test_tools() -> void:
	print("-- Ferramentas (clique) --")
	var world := await _new_world()
	var inv := _inv(world)
	var player := world.get_node("Player") as CharacterBody3D
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var weapon := player.get_node("Visual/Weapon") as WeaponController
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var tree := world.get_node("ResourceField/DeadTrees/DeadTree01") as ResourceNode
	var stone := world.get_node("ResourceField/StonePiles/StonePile01") as ResourceNode
	var bush := world.get_node("ResourceField/BerryBushs/BerryBush01") as ResourceNode
	for n in [tree, stone, bush]:
		n.yield_multiplier = 1.0

	# À mão ([E]): galhos e pedrinhas, 1 de cada vez; frutas normais.
	_check(tree.get_interaction_prompt_for(detector) == "Juntar galhos", "Árvore seca à mão: 'Juntar galhos'", tree.get_interaction_prompt_for(detector))
	var r := tree.interact(detector)
	_check(r["ok"] and inv.count(&"wood") == 1, "À mão: só 1 madeira (galhos)")
	r = stone.interact(detector)
	_check(r["ok"] and inv.count(&"stone") == 1 and stone.get_interaction_prompt_for(detector) == "Pegar pedrinhas", "À mão: só 1 pedra (pedrinhas)")
	bush.interact(detector)
	_check(inv.count(&"wild_berries") == bush.amount_per_harvest, "Frutas não pedem ferramenta")

	# Machado na mão: o [E] pede clique; o clique (golpe) corta com bônus.
	inv.add_all({&"stone_axe": 1, &"stone_pickaxe": 1})
	_check(not weapon.tool_strike().get("ok", false), "Machado só no inventário: clique não corta")
	equipment.select_slot(equipment.slot_of(&"stone_axe"))
	_check(detector.held_tool != null and detector.held_tool.chop_power > 0, "Machado na mão tem força de corte")
	_check(tree.get_interaction_prompt_for(detector).begins_with("[Clique] Cortar"), "Com machado: aviso pede clique", tree.get_interaction_prompt_for(detector))
	r = tree.interact(detector)
	_check(not r["ok"] and inv.count(&"wood") == 1, "Com machado, o [E] não corta")
	_face(player, tree.global_position)
	player.global_position = tree.global_position + Vector3(0, 0.1, 1.4)
	_face(player, tree.global_position)
	await _wait(3)
	var before := inv.count(&"wood")
	r = weapon.tool_strike()
	_check(r.get("ok", false) and inv.count(&"wood") == before + tree.amount_per_harvest + 2, "Clique com machado: coleta completa +2", str(inv.count(&"wood") - before))
	_check(String(r.get("message", "")).contains("Machado"), "Aviso cita o machado", r.get("message", ""))
	var stone_before := inv.count(&"stone")
	weapon.tool_strike()
	_check(inv.count(&"stone") == stone_before, "Machado não quebra pedra")

	equipment.select_slot(equipment.slot_of(&"stone_pickaxe"))
	player.global_position = stone.global_position + Vector3(0, 0.1, 1.4)
	_face(player, stone.global_position)
	await _wait(3)
	r = weapon.tool_strike()
	_check(r.get("ok", false) and inv.count(&"stone") == stone_before + stone.amount_per_harvest + 2, "Clique com picareta: pedra completa +2")
	player.global_position = stone.global_position + Vector3(0, 0.1, 6.0)
	await _wait(3)
	_check(weapon.tool_strike().is_empty(), "Longe demais: o golpe não acerta nada")
	await _free_world(world)


func _test_forest_tree() -> void:
	print("-- Árvores da floresta --")
	var world := await _new_world()
	var inv := _inv(world)
	var forest := world.get_node("TestWorld/Forest") as ForestGenerator
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var player := world.get_node("Player") as CharacterBody3D
	var weapon := player.get_node("Visual/Weapon") as WeaponController
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var tree := forest.tree_bodies[0] as ForestTree
	_check(tree != null and (tree.collision_layer & 4) != 0, "Árvores da floresta são interativas")
	player.global_position = tree.global_position + Vector3(1.2, 0.1, 0)
	_face(player, tree.global_position)
	await _wait(3)
	detector.refresh_focus()
	_check(not (detector.get_focused() is ForestTree), "Sem machado na mão, árvores não viram alvo do aviso")
	_check(weapon.tool_strike().is_empty() and inv.count(&"wood") == 0, "Clique com a clava não corta")
	inv.add_item(&"stone_axe", 1)
	equipment.select_slot(equipment.slot_of(&"stone_axe"))
	detector.refresh_focus()
	_check(detector.get_focused() is ForestTree, "Machado na mão: a árvore vira alvo", str(detector.get_focused()))
	var marker := world.get_node("InteractionMarker") as InteractionMarker
	await _wait(2)
	_check((marker.get_node("Key") as Label3D).text == "Clique", "Indicador mostra 'Clique'")
	var target := weapon.tool_target() as ForestTree
	_check(target != null, "Golpe encontra a árvore à frente")
	var xp := experience.total_xp
	var r := weapon.tool_strike()
	_check(r.get("ok", false) and target.hits == 1 and inv.count(&"wood") == 0, "1º golpe: 1/3, ainda sem madeira", r.get("message", ""))
	r = weapon.tool_strike()
	_check(target.hits == 2 and String(r.get("message", "")).contains("2/3"), "2º golpe: 2/3")
	r = weapon.tool_strike()
	_check(r.get("felled", false) and inv.count(&"wood") == 5, "3º golpe derruba: +5 madeira (3 + bônus 2)", str(inv.count(&"wood")))
	_check(experience.total_xp > xp, "Derrubar dá XP de coleta")
	r = weapon.tool_strike()
	_check(not r.get("ok", true) and inv.count(&"wood") == 5, "Derrubada: precisa de tempo para render de novo")

	# Machados melhores (dados): mais força derruba em menos golpes.
	var strong := (load("res://resources/combat/stone_axe.tres") as WeaponDefinition).duplicate() as WeaponDefinition
	strong.chop_power = 3
	var other := forest.tree_bodies[1] as ForestTree
	r = other.tool_strike(detector, strong)
	_check(r.get("felled", false), "Machado com força 3 derruba em 1 golpe")
	await _free_world(world)


## Vira o personagem para olhar [param point] (o modelo olha para -Z).
func _face(player: CharacterBody3D, point: Vector3) -> void:
	var to := point - player.global_position
	(player.get_node("Visual") as Node3D).rotation.y = atan2(-to.x, -to.z)


func _test_equipment() -> void:
	print("-- Equipamento --")
	var world := await _new_world()
	var inv := _inv(world)
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var weapon := world.get_node("Player/Visual/Weapon") as WeaponController
	_check(weapon.definition.id == &"improvised_club", "Começa com a clava")
	inv.add_item(&"stone_spear", 1)
	_check(weapon.definition.id == &"improvised_club", "Lança nova vai para a hotbar, sem trocar a arma sozinha")
	_check(equipment.slot_of(&"stone_spear") > 0, "Lança ganha um espaço na hotbar")
	equipment.select_slot(equipment.slot_of(&"stone_spear"))
	_check(weapon.definition.id == &"stone_spear" and weapon.definition.damage > 12.0 and weapon.definition.reach > 1.8, "Lança selecionada: na mão, mais dano e alcance")
	var spear_visual := weapon.get_node_or_null("Club/StoneSpear") as Node3D
	_check(spear_visual != null and spear_visual.visible and not (weapon.get_node("Club/Head") as Node3D).visible, "Visual troca para a lança")
	inv.remove_item(&"stone_spear", 1)
	_check(weapon.definition.id == &"improvised_club" and (weapon.get_node("Club/Head") as Node3D).visible, "Sem a lança: volta à clava")

	_check(not equipment.toggle_torch() and not equipment.torch_lit, "Sem tocha: não acende")
	inv.add_item(&"torch", 1)
	_check(equipment.toggle_torch() and equipment.torch_lit, "Com tocha: acende")
	var light := world.get_node("Player/Visual/Torch") as Node3D
	_check(light != null and light.visible, "Tocha visível com luz")
	inv.remove_item(&"torch", 1)
	_check(not equipment.torch_lit and not light.visible, "Perder a tocha apaga")

	var health := world.get_node("Player/Health") as HealthComponent
	inv.add_item(&"bandage", 2)
	_check(not equipment.use_bandage() and inv.count(&"bandage") == 2, "Vida cheia: atadura não é gasta")
	health.apply_damage(DamageInfo.create(50.0, &"enemy:test"))
	_check(equipment.use_bandage() and absf(health.current_health - 80.0) < 0.1 and inv.count(&"bandage") == 1, "Atadura cura 30")
	_check(not equipment.use_bandage() and inv.count(&"bandage") == 1, "Intervalo entre ataduras")
	await _free_world(world)


func _test_boar_loot() -> void:
	print("-- Carne de javali --")
	var world := await _new_world()
	var inv := _inv(world)
	var boar := world.get_node("Enemies/SpinyBoar1") as HostileCreature
	var enemies_before := world.get_node("Enemies").get_child_count()
	boar.receive_damage(DamageInfo.create(1000.0, &"player:test", &"physical"))
	await _wait(2)
	var drops := world.find_children("*", "LootDrop", true, false)
	_check(drops.size() == 1, "Javali abatido deixa carne no chão")
	_check(world.get_node("Enemies").get_child_count() == enemies_before, "Carne não conta como hostil")
	var drop := drops[0] as LootDrop
	_check(drop.get_interaction_prompt().contains("Carne crua"), "Aviso '[E] Pegar 2 Carne crua'", drop.get_interaction_prompt())
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	inv.capacity = 1
	inv.load_counts({&"wood": 50})
	var r := drop.interact(detector)
	_check(not r["ok"] and is_instance_valid(drop), "Inventário cheio: a carne fica no chão")
	inv.capacity = 20
	inv.load_counts({})
	r = drop.interact(detector)
	_check(r["ok"] and inv.count(&"raw_meat") == 2, "Pega 2 carnes cruas")
	await _wait(2)
	_check(not is_instance_valid(drop), "Vazio, o monte some")
	await _free_world(world)


# ---------- menu ----------

func _test_menu() -> void:
	print("-- Menu --")
	var world := await _new_world()
	var menu := world.get_node("CraftingMenu") as CraftingMenu
	var inv := _inv(world)
	_check(not menu.is_open, "Começa fechado")
	_check(menu.open() and menu.is_open, "Abre")
	_check(menu.row_text(&"recipe_stone_axe").contains("Madeira 0/3"), "Mostra custos com o que você tem", menu.row_text(&"recipe_stone_axe"))
	_check(menu.row_text(&"recipe_stone_spear").contains("suba de nível"), "Receita bloqueada explica", menu.row_text(&"recipe_stone_spear"))
	inv.add_all({&"wood": 1, &"fiber": 2})
	await _wait(1)
	_check(menu.row_text(&"recipe_torch").contains("Pronto"), "Atualiza quando o inventário muda", menu.row_text(&"recipe_torch"))
	var r := menu.craft_by_id(&"recipe_torch")
	_check(r["ok"] and inv.has_item(&"torch"), "Fabricar pelo menu")
	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	_check(hud.get_message().contains("Tocha"), "Aviso no HUD", hud.get_message())
	menu.close()
	_check(not menu.is_open, "Fecha")
	var controller := world.get_node("PlacementController") as PlacementController
	controller.enter()
	_check(not menu.open() and not menu.is_open, "Não abre no modo de construção")
	controller.exit()
	await _free_world(world)


func _test_save() -> void:
	print("-- Save --")
	var world := await _new_world()
	var inv := _inv(world)
	inv.add_all({&"stone_axe": 1, &"stone_spear": 1, &"bandage": 3, &"cooked_meat": 2})
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	equipment.select_slot(equipment.slot_of(&"stone_spear"))
	var slots_before := equipment.slots.duplicate()
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com ferramentas")
	await _free_world(world)
	var again := await _new_world()
	var save2 := again.get_node("SaveManager") as SaveManager
	_check(await save2.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	var inv2 := _inv(again)
	_check(inv2.has_item(&"stone_axe") and inv2.count(&"bandage") == 3 and inv2.count(&"cooked_meat") == 2, "Ferramentas e itens restaurados")
	var weapon := again.get_node("Player/Visual/Weapon") as WeaponController
	_check(weapon.definition.id == &"stone_spear", "Lança volta na mão")
	var equipment2 := again.get_node("PlayerEquipment") as PlayerEquipment
	_check(equipment2.slots == slots_before, "Hotbar restaurada na mesma ordem", str(equipment2.slots))
	await _free_world(again)
	_wipe_dir()


# ---------- hotbar ----------

func _test_hotbar() -> void:
	print("-- Hotbar --")
	var world := await _new_world()
	var inv := _inv(world)
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	_check(equipment.slots.size() == 9 and equipment.slots[0] == &"improvised_club", "9 espaços; o 1 é a clava")
	_check(equipment.held_item == &"improvised_club" and detector.held_item == &"improvised_club", "Começa com a clava na mão")
	inv.add_all({&"stone_pickaxe": 1, &"torch": 1, &"bandage": 2, &"cooked_meat": 1, &"wood": 5})
	_check(equipment.slot_of(&"stone_pickaxe") > 0 and equipment.slot_of(&"torch") > 0 and equipment.slot_of(&"bandage") > 0 and equipment.slot_of(&"cooked_meat") > 0, "Itens úteis entram sozinhos na hotbar")
	_check(equipment.slot_of(&"wood") < 0, "Materiais não ocupam a hotbar")
	equipment.select_slot(equipment.slot_of(&"stone_pickaxe"))
	_check(equipment.held_item == &"stone_pickaxe" and detector.held_item == &"stone_pickaxe", "Número escolhe o item na mão")
	var torch_slot := equipment.slot_of(&"torch")
	equipment.select_slot(torch_slot)
	_check(equipment.torch_lit and equipment.held_item == &"stone_pickaxe", "Tocha acende sem largar a ferramenta")
	var health := world.get_node("Player/Health") as HealthComponent
	health.apply_damage(DamageInfo.create(40.0, &"enemy:test"))
	equipment.select_slot(equipment.slot_of(&"bandage"))
	_check(inv.count(&"bandage") == 1 and health.current_health > 60.0, "Espaço da atadura cura")
	var hunger := world.get_node("Player/Hunger") as HungerComponent
	hunger.set_hunger(30.0)
	var meat_slot := equipment.slot_of(&"cooked_meat")
	equipment.select_slot(meat_slot)
	_check(not inv.has_item(&"cooked_meat") and hunger.current_hunger > 60.0, "Espaço da comida come")
	_check(equipment.slots[meat_slot] == &"", "Item que acabou libera o espaço")
	equipment.cycle_held(1)
	_check(equipment.held_item == &"improvised_club", "Roda do mouse passa para o próximo item de mão")
	equipment.select_slot(equipment.slot_of(&"stone_pickaxe"))
	inv.remove_item(&"stone_pickaxe", 1)
	_check(equipment.held_item == &"improvised_club", "Perder o item na mão volta para a clava")
	var placement := world.get_node("PlacementController") as PlacementController
	placement.enter()
	_check(not equipment._hotbar_input_allowed(), "No modo de construção, os números escolhem peças")
	placement.exit()

	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	var bar := hud.get_hotbar()
	await _wait(2)
	_check(bar != null and bar.get_slot_count() == 9, "Hotbar visual com 9 espaços")
	_check(bar.get_slot_item(0) == &"improvised_club" and bar.get_slot_item(torch_slot) == &"torch", "Ícones seguem a hotbar")
	_check(not hud.is_inventory_open(), "Inventário começa fechado")
	hud.toggle_inventory()
	_check(hud.is_inventory_open(), "[I] abre o inventário")
	hud.toggle_inventory()
	_check(not hud.is_inventory_open(), "[I] fecha o inventário")
	await _free_world(world)


func _test_marker() -> void:
	print("-- Indicador de interação --")
	var world := await _new_world()
	var marker := world.get_node("InteractionMarker") as InteractionMarker
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var player := world.get_node("Player") as CharacterBody3D
	var bush := world.get_node("ResourceField/BerryBushs/BerryBush01") as Node3D
	_check(not marker.is_showing(), "Sem nada perto: indicador escondido")
	player.global_position = bush.global_position + Vector3(0, 0.1, 1.6)
	await _wait(3)
	detector.refresh_focus()
	await _wait(10)
	_check(marker.is_showing() and marker.target == bush, "Perto do arbusto: indicador aparece nele")
	var gem := marker.get_node("Gem") as Node3D
	_check(gem.global_position.y > bush.global_position.y + 0.6, "Losango fica acima do objeto")
	var y1 := gem.global_position.y
	await _wait(12)
	_check(not is_equal_approx(gem.global_position.y, y1), "Losango se mexe (animação)")
	player.global_position = Vector3(30, 0.1, 30)  # campo aberto, nada interativo perto
	await _wait(3)
	detector.refresh_focus()
	await _wait(20)
	_check(detector.get_focused() == null and not marker.is_showing(), "Longe de tudo: indicador some", str(detector.get_focused()))
	await _free_world(world)


# ---------- sílex ----------

func _test_flint() -> void:
	print("-- Sílex --")
	var world := await _new_world()
	var inv := _inv(world)
	var crafting := _crafting(world)
	var player := world.get_node("Player") as CharacterBody3D
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var weapon := player.get_node("Visual/Weapon") as WeaponController
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var scatter := world.get_node("ResourceField") as ResourceScatter
	var outcrops := []
	for node in scatter.spawned:
		if String(node.name).ends_with("_flint"):
			outcrops.append(node)
	_check(inv.catalog.has_item(&"flint") and outcrops.size() >= 10, "Afloramentos de sílex espalhados pelo mapa", str(outcrops.size()))
	var outcrop := outcrops[0] as ResourceNode
	outcrop.yield_multiplier = 1.0
	_check(outcrop.required_tool() == &"pickaxe" and outcrop.get_interaction_prompt_for(detector) == "Pegar lascas de sílex", "Sílex pede picareta; à mão, só lascas")
	outcrop.interact(detector)
	_check(inv.count(&"flint") == 1, "À mão: 1 sílex")
	inv.add_item(&"stone_pickaxe", 1)
	equipment.select_slot(equipment.slot_of(&"stone_pickaxe"))
	player.global_position = outcrop.global_position + Vector3(0, 0.1, 1.4)
	_face(player, outcrop.global_position)
	await _wait(3)
	weapon.tool_strike()
	_check(inv.count(&"flint") == 1 + outcrop.amount_per_harvest + 2, "Picareta no afloramento: +4 sílex", str(inv.count(&"flint")))

	var stone := world.get_node("ResourceField/StonePiles/StonePile01") as ResourceNode
	stone.bonus_chance = 1.0
	player.global_position = stone.global_position + Vector3(0, 0.1, 1.4)
	_face(player, stone.global_position)
	await _wait(3)
	var before := inv.count(&"flint")
	var r := weapon.tool_strike()
	_check(inv.count(&"flint") == before + 1 and String(r.get("message", "")).contains("Sílex"), "Quebrar pedra pode soltar sílex", r.get("message", ""))

	inv.add_all({&"wood": 6, &"flint": 10, &"fiber": 6})
	var axe := crafting.get_recipe(&"recipe_flint_axe")
	_check(crafting.status(axe) == CraftingManager.LOCKED, "Ferramentas de sílex bloqueadas antes do nível 3")
	(world.get_node("Progression/LevelManager") as LevelManager).sync_to_xp(250)
	_check(crafting.status(axe) == CraftingManager.READY, "Nível 3 libera o machado de sílex")
	_check(crafting.craft(axe)["ok"] and crafting.craft(crafting.get_recipe(&"recipe_flint_pickaxe"))["ok"], "Fabrica machado e picareta de sílex")
	_check(equipment.slot_of(&"flint_axe") > 0 and equipment.slot_of(&"flint_pickaxe") > 0, "Ferramentas novas entram na hotbar")
	equipment.select_slot(equipment.slot_of(&"flint_axe"))
	_check(weapon.definition.id == &"flint_axe" and weapon.definition.chop_power == 2, "Machado de sílex na mão (força 2)")
	var visual := weapon.get_node_or_null("Club/FlintAxe") as Node3D
	_check(visual != null and visual.visible and not (weapon.get_node("Club/Head") as Node3D).visible, "Visual montado a partir dos dados")
	var tree := (world.get_node("TestWorld/Forest") as ForestGenerator).tree_bodies[2] as ForestTree
	var wood := inv.count(&"wood")
	tree.tool_strike(detector, weapon.definition)
	r = tree.tool_strike(detector, weapon.definition)
	_check(r.get("felled", false) and inv.count(&"wood") == wood + 7, "Machado de sílex: 2 golpes e +7 madeira (3 + 4)", str(inv.count(&"wood") - wood))
	await _free_world(world)
