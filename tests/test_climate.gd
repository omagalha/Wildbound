extends SceneTree
## Testes de frio e calor: temperatura por região, fogo, roupas e dano.
##
## Uso: godot --headless --path . --script res://tests/test_climate.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_climate"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do clima ==")
	_wipe_dir()
	await _test_climate()
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
	await _wait(4)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	(world.get_node("TestWorld/DayNight") as DayNightCycle).set_process(false)
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


## Leva o corpo até a temperatura do lugar.
func _settle(temp: TemperatureComponent) -> void:
	temp.body_temp = temp.effective_temperature()
	temp.tick(0.01)


func _test_climate() -> void:
	var world := await _new_world()
	var temp := world.get_node("Temperature") as TemperatureComponent
	temp.set_physics_process(false)
	var player := world.get_node("Player") as CharacterBody3D
	var island := world.get_node("TestWorld/Island") as IslandTerrain
	var health := player.get_node("Health") as HealthComponent
	var hunger := player.get_node("Hunger") as HungerComponent
	var inv := player.get_node("Inventory") as Inventory
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	var cycle := world.get_node("TestWorld/DayNight") as DayNightCycle
	cycle.hour = 12.0

	player.global_position = Vector3(0, 0.1, 30)
	_settle(temp)
	_check(temp.status == &"comfort" and absf(temp.body_temp - 20.0) < 1.0, "Floresta de dia: confortável (~20 °C)", "%.1f" % temp.body_temp)

	# Pico gelado
	var peak := Vector3(0, island.height_at(0, -470), -470)
	player.global_position = peak
	_check(temp.ambient_temperature() < TemperatureComponent.FREEZING, "Alto das montanhas: abaixo de zero", "%.1f" % temp.ambient_temperature())
	temp.body_temp = 20.0
	temp.tick(1.0)
	_check(temp.body_temp < 20.0 and temp.body_temp > 10.0, "O corpo esfria aos poucos", "%.1f" % temp.body_temp)
	_settle(temp)
	_check(temp.status == &"freezing", "Sem roupa: congelando", temp.status)
	var hp := health.current_health
	temp.tick(2.1)
	_check(health.current_health < hp, "Congelando: perde vida")
	_check(hunger.debug_multiplier > 1.0, "Com frio, a fome cai mais rápido")
	inv.add_all({&"hide": 4, &"fiber": 4})
	var crafting := world.get_node("CraftingManager") as CraftingManager
	_check(crafting.craft(crafting.get_recipe(&"recipe_fur_coat"))["ok"], "Fabrica o casaco de pele (pele + fibra)")
	_check(equipment.slot_of(&"fur_coat") > 0, "Casaco vai para a barra")
	equipment.select_slot(equipment.slot_of(&"fur_coat"))
	_check(equipment.worn_item == &"fur_coat" and equipment.worn_protection().x >= 25.0, "Número veste o casaco")
	_settle(temp)
	_check(temp.status != &"freezing", "De casaco, não congela", "%.1f %s" % [temp.body_temp, temp.status])
	equipment.select_slot(equipment.slot_of(&"fur_coat"))
	_check(equipment.worn_item == &"", "Mesmo número tira")

	# Fogo aquece
	player.global_position = peak
	var fire := FireLight.new()
	fire.radius = 9.0
	world.add_child(fire)
	fire.global_position = peak
	_settle(temp)
	_check(temp.status == &"comfort", "Perto do fogo: aquece", "%.1f" % temp.body_temp)
	fire.queue_free()
	await _wait(1)

	# Noite esfria
	player.global_position = Vector3(0, 0.1, 30)
	cycle.hour = 23.0
	_check(absf(temp.ambient_temperature() - 12.0) < 0.5, "Noite: 8 °C mais frio")
	cycle.hour = 12.0

	# Vulcão
	var crater := Vector3(island.volcano_center.x + 40, 0, island.volcano_center.y)
	crater.y = island.height_at(crater.x, crater.z)
	player.global_position = crater
	_settle(temp)
	_check(temp.status == &"burning", "Perto da cratera: queimando", "%.1f" % temp.body_temp)
	inv.add_all({&"ice_crystal": 3, &"clay": 2, &"fiber": 6})
	crafting.craft(crafting.get_recipe(&"recipe_cooling_cloak"))
	equipment.select_slot(equipment.slot_of(&"cooling_cloak"))
	_settle(temp)
	_check(equipment.worn_item == &"cooling_cloak" and temp.status != &"burning", "Manto refrescante evita queimar", "%.1f" % temp.body_temp)

	# Morte de frio tem mensagem própria
	equipment.wear(&"")
	player.global_position = peak
	_settle(temp)
	health.current_health = 2.0
	temp.tick(2.1)
	await _wait(2)
	var hud := world.get_node("SurvivalHUD") as SurvivalHUD
	_check(health.is_dead() and hud.get_message().contains("congelado"), "Morrer de frio: 'Você morreu congelado'", hud.get_message())

	# Pele vem dos animais e a roupa vestida vai para o save
	var boar := world.get_node("Enemies/SpinyBoar1") as HostileCreature
	_check(boar.definition.loot.has(&"hide"), "Javali deixa pele")
	await _free_world(world)

	var w2 := await _new_world()
	var eq2 := w2.get_node("PlayerEquipment") as PlayerEquipment
	(w2.get_node("Player/Inventory") as Inventory).add_item(&"fur_coat", 1)
	eq2.wear(&"fur_coat")
	_check((w2.get_node("SaveManager") as SaveManager).save_game(), "Salvar vestido")
	await _free_world(w2)
	var w3 := await _new_world()
	_check(await (w3.get_node("SaveManager") as SaveManager).load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	_check((w3.get_node("PlayerEquipment") as PlayerEquipment).worn_item == &"fur_coat", "Roupa vestida volta do save")
	await _free_world(w3)
