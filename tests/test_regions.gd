extends SceneTree
## Testes das regiões: recursos próprios, receitas que os usam e criaturas.
##
## Uso: godot --headless --path . --script res://tests/test_regions.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_regions"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes das regiões ==")
	await _test_resources()
	await _test_creatures()
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
	await _wait(4)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


func _region_nodes(world: Node, item_id: StringName) -> Array:
	var out := []
	for node in (world.get_node("ResourceField") as ResourceScatter).spawned:
		if String(node.name).ends_with("_region") and node.item.id == item_id:
			out.append(node)
	return out


# ---------- recursos ----------

func _test_resources() -> void:
	print("-- Recursos das regiões --")
	var world := await _new_world()
	var island := world.get_node("TestWorld/Island") as IslandTerrain
	var B := IslandTerrain.Biome
	var expected := {&"ice_crystal": B.SNOW, &"clay": B.ROCKY, &"obsidian": B.VOLCANIC, &"sulfur": B.VOLCANIC, &"golden_berries": B.PLAINS, &"coconut": B.BEACH}
	for id in expected:
		var nodes := _region_nodes(world, id)
		var right_place := 0
		for n in nodes:
			var b := island.biome_at(n.global_position.x, n.global_position.z)
			if b == expected[id] or b == B.BEACH or b == B.FOREST:
				right_place += 1
		_check(nodes.size() >= 8 and right_place >= nodes.size() * 0.8, "%s na região certa" % id, "%d nós, %d no lugar" % [nodes.size(), right_place])
	var one := _region_nodes(world, &"obsidian")[0] as ResourceNode
	_check(absf(one.global_position.y - island.height_at(one.global_position.x, one.global_position.z)) < 0.1, "Recursos ficam na altura do relevo")

	# Ferramentas certas
	var player := world.get_node("Player") as CharacterBody3D
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var inv := player.get_node("Inventory") as Inventory
	var flint_pick := load("res://resources/combat/flint_pickaxe.tres") as WeaponDefinition
	var iron_pick := load("res://resources/combat/iron_pickaxe.tres") as WeaponDefinition
	var obs := _region_nodes(world, &"obsidian")[0] as ResourceNode
	_check(not obs.interact(detector)["ok"], "Obsidiana: nada à mão")
	_check(not obs.tool_strike(detector, flint_pick)["ok"], "Obsidiana: picareta de sílex fraca demais")
	_check(obs.tool_strike(detector, iron_pick)["ok"] and inv.count(&"obsidian") > 0, "Obsidiana: picareta de ferro quebra")
	var ice := _region_nodes(world, &"ice_crystal")[0] as ResourceNode
	_check(ice.tool_strike(detector, flint_pick)["ok"] and inv.count(&"ice_crystal") > 0, "Cristal de gelo: picareta de sílex basta")
	var clay := _region_nodes(world, &"clay")[0] as ResourceNode
	_check(clay.interact(detector)["ok"] and inv.count(&"clay") > 0, "Argila: à mão")
	var coco := _region_nodes(world, &"coconut")[0] as ResourceNode
	coco.interact(detector)
	_check(inv.catalog.get_item(&"coconut").is_food() and inv.count(&"coconut") > 0, "Coco: comida da praia")

	# Receitas
	var crafting := world.get_node("CraftingManager") as CraftingManager
	(world.get_node("Progression/LevelManager") as LevelManager).sync_to_xp(700)
	inv.load_counts({&"raw_meat": 2, &"golden_berries": 5, &"ice_crystal": 3, &"obsidian": 4, &"iron_ingot": 2, &"wood": 2})
	_check(crafting.status(crafting.get_recipe(&"recipe_golden_stew")) == CraftingManager.NEEDS_STATION, "Ensopado pede fogueira")
	_check(crafting.status(crafting.get_recipe(&"recipe_obsidian_sword")) == CraftingManager.NEEDS_STATION, "Espada de obsidiana pede fornalha")
	_check(inv.catalog.get_item(&"golden_stew").food_value >= 70.0, "Ensopado dourado: +70 de fome")
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	inv.add_item(&"frost_elixir", 1)
	var health := player.get_node("Health") as HealthComponent
	health.apply_damage(DamageInfo.create(70.0, &"enemy:test"))
	_check(equipment.select_slot(equipment.slot_of(&"frost_elixir")) and health.current_health >= 89.0, "Elixir de gelo cura 60 pela barra")
	var placement := world.get_node("PlacementController") as PlacementController
	var has_brazier := false
	for piece in placement.catalog.pieces:
		if piece.id == &"building_watch_brazier" and piece.cost.has(&"sulfur") and piece.cost.has(&"clay"):
			has_brazier = true
	_check(has_brazier, "Braseiro de vigília usa enxofre e argila")
	await _free_world(world)


# ---------- criaturas ----------

func _test_creatures() -> void:
	print("-- Criaturas das regiões --")
	var world := await _new_world()
	await _wait(3)
	var regions := world.get_node("RegionCreatures") as RegionCreatures
	var island := world.get_node("TestWorld/Island") as IslandTerrain
	for id in [&"snow_wolf", &"rock_bull", &"ember_hound", &"horned_stag"]:
		_check(regions.species_of(id).size() >= 4, "%s nas tocas" % id, str(regions.species_of(id).size()))
	var bull := regions.species_of(&"rock_bull")[0]
	_check(island.biome_at(bull.global_position.x, bull.global_position.z) == IslandTerrain.Biome.ROCKY, "Touro nas Terras Rochosas")
	_check(bull.definition.max_health > regions.species_of(&"snow_wolf")[0].definition.max_health, "Touro mais resistente que o lobo")
	var model := bull.get_node("CreatureModel") as CreatureModel
	_check(model.model != null and model.has_clip("attack"), "Touro com modelo e animação de chifrada")
	_check(regions.nests.size() >= 16, "Tocas viram zonas de atenção", str(regions.nests.size()))
	_check(regions.awake_count() < regions.creatures.size() / 2, "Criaturas longe do jogador dormem", "%d/%d" % [regions.awake_count(), regions.creatures.size()])
	var player := world.get_node("Player") as CharacterBody3D
	player.global_position = bull.global_position + Vector3(20, 2, 0)
	regions.update_sleep()
	_check(bull.process_mode != Node.PROCESS_MODE_DISABLED, "Chegar perto acorda")
	var hp := bull.health.max_health
	var diff := world.get_node("DifficultyManager") as DifficultyManager
	diff.apply(diff.get_preset(&"hard"))
	_check(bull.health.max_health > hp, "Dificuldade Difícil deixa as criaturas mais fortes")
	bull.receive_damage(DamageInfo.create(10000.0, &"player:test"))
	await _wait(3)
	var drops := world.find_children("*", "LootDrop", true, false)
	var meat := false
	for d in drops:
		if (d as LootDrop).items.has(&"raw_meat") and int((d as LootDrop).items[&"raw_meat"]) >= 4:
			meat = true
	_check(meat, "Touro abatido deixa 4 carnes e argila")
	await _free_world(world)
