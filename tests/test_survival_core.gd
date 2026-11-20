extends SceneTree
## Testes do núcleo de sobrevivência (WLD-006 mínimo, WLD-011 parcial, WLD-017, respawn simples).
##
## Uso (na pasta do projeto):
##   godot --headless --path . --script res://tests/test_survival_core.gd
##
## Código de saída 0 = todos passaram; 1 = alguma falha.
## Os ids entre colchetes ([S06], [DR12]...) apontam para os casos das especificações em docs/systems/.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const CATALOG := "res://resources/items/item_catalog.tres"
const BERRY_BUSH := "res://scenes/world/resources/berry_bush.tscn"

var _passed := 0
var _failed := 0
var _catalog: ItemCatalog


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do núcleo de sobrevivência ==")
	_catalog = load(CATALOG) as ItemCatalog
	_test_input_and_catalog()
	_test_inventory()
	_test_health()
	_test_hunger()
	_test_food()
	_test_starvation()
	_test_resource_node()
	await _test_main_scene_integration()
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


func _wait_physics(frames: int) -> void:
	for i in frames:
		await physics_frame


func _new_inventory(capacity: int = 20) -> Inventory:
	var inventory := Inventory.new()
	inventory.catalog = _catalog
	inventory.capacity = capacity
	return inventory


func _new_hunger() -> HungerComponent:
	var hunger := HungerComponent.new()
	hunger.current_hunger = hunger.max_hunger
	return hunger


func _new_health() -> HealthComponent:
	var health := HealthComponent.new()
	health.current_health = health.max_health
	return health


func _simulate(node: Node, seconds: float, steps_per_second: int) -> void:
	var dt := 1.0 / steps_per_second
	for i in int(round(seconds * steps_per_second)):
		node.tick(dt)


# ---------- estrutura ----------

func _test_input_and_catalog() -> void:
	for pair in [[&"interact", KEY_E], [&"eat", KEY_F]]:
		var found := false
		if InputMap.has_action(pair[0]):
			for ev in InputMap.action_get_events(pair[0]):
				if ev is InputEventKey and (ev as InputEventKey).physical_keycode == pair[1]:
					found = true
		_check(found, "InputMap: '%s' -> %s" % [pair[0], OS.get_keycode_string(pair[1])])
	_check(_catalog != null and _catalog.has_item(&"wood") and _catalog.has_item(&"stone") and _catalog.has_item(&"fiber") and _catalog.has_item(&"wild_berries"), "Catálogo tem madeira, pedra, fibra e frutas")
	var berries := _catalog.get_item(&"wild_berries") if _catalog else null
	_check(berries != null and is_equal_approx(berries.food_value, 15.0), "Frutas silvestres restauram 15 de fome")
	var wood := _catalog.get_item(&"wood") if _catalog else null
	_check(wood != null and not wood.is_food(), "Madeira não é comida")


# ---------- inventário ----------

func _test_inventory() -> void:
	var inv := _new_inventory(2)
	_check(inv.add_item(&"wood", 30), "Inventário: adiciona 30 madeira")
	_check(inv.count(&"wood") == 30 and inv.used_slots() == 1, "Inventário: 30 madeira ocupam 1 espaço (pilha de 50)")
	_check(inv.add_item(&"wood", 20) and inv.used_slots() == 1, "Inventário: completa a pilha sem novo espaço")
	_check(inv.add_item(&"wild_berries", 20) and inv.used_slots() == 2, "Inventário: frutas usam outro espaço")
	var before := inv.get_all()
	_check(not inv.add_item(&"stone", 1) and inv.get_all() == before, "Inventário cheio: adição recusada sem mudar nada")
	_check(not inv.add_item(&"wood", 1), "Inventário cheio: pilha cheia não aceita mais")
	_check(inv.space_for(&"wild_berries") == 0 and inv.space_for(&"wood") == 0, "Inventário: espaço livre calculado corretamente")
	_check(not inv.remove_item(&"wood", 51) and inv.count(&"wood") == 50, "Remoção maior que o estoque é recusada sem mudar nada")
	_check(inv.remove_item(&"wood", 50) and inv.count(&"wood") == 0 and inv.used_slots() == 1, "Remover tudo libera o espaço")
	_check(not inv.add_item(&"unknown_item", 1), "Item fora do catálogo é recusado")
	_check(not inv.add_item(&"wood", 0) and not inv.remove_item(&"wood", 0), "Quantidade zero é recusada")
	var emitted := [0]
	inv.changed.connect(func(): emitted[0] += 1)
	inv.add_item(&"stone", 1)
	inv.add_item(&"stone", 999)  # recusada: não deve emitir
	_check(emitted[0] == 1, "Sinal 'changed' só quando algo muda")
	_check(inv.first_food() != null and inv.first_food().id == &"wild_berries", "first_food encontra as frutas")
	inv.free()


# ---------- vida ----------

func _test_health() -> void:
	var health := _new_health()
	var deaths := []
	health.died.connect(func(c): deaths.append(c))
	_check(is_equal_approx(health.apply_damage(DamageInfo.create(30.0, &"enemy:test")), 30.0) and is_equal_approx(health.current_health, 70.0), "Vida: dano com causa reduz a vida [A01]")
	_check(health.apply_damage(DamageInfo.create(10.0, &"")) == 0.0 and is_equal_approx(health.current_health, 70.0), "Vida: pacote sem causa é recusado [HC15]")
	_check(is_equal_approx(health.heal(100.0), 30.0) and is_equal_approx(health.current_health, 100.0), "Vida: cura não passa do máximo [A04]")
	health.accepts_damage = false
	_check(health.apply_damage(DamageInfo.create(10.0, &"enemy:test")) == 0.0, "Vida: proteção ignora dano")
	health.accepts_damage = true
	health.apply_damage(DamageInfo.create(500.0, &"enemy:test"))
	health.apply_damage(DamageInfo.create(5.0, &"enemy:test"))
	_check(health.is_dead() and health.current_health == 0.0, "Vida: chega a 0 sem ficar negativa [A03]")
	_check(deaths == [&"enemy:test"], "Vida: 'died' emitido uma única vez, com a causa [A03]")
	_check(health.heal(50.0) == 0.0, "Vida: morto não é curado")
	health.revive(75.0)
	_check(not health.is_dead() and is_equal_approx(health.current_health, 75.0), "Vida: revive com a vida informada")
	health.free()


# ---------- fome ----------

func _test_hunger() -> void:
	var hunger := _new_hunger()
	_simulate(hunger, 600.0, 60)
	_check(absf(hunger.current_hunger - 90.0) < 0.01, "Fome: 10 min no Intermediário = 90 [S01]", "%.3f" % hunger.current_hunger)

	var coarse := _new_hunger()
	var fine := _new_hunger()
	_simulate(coarse, 600.0, 30)
	_simulate(fine, 600.0, 120)
	_check(absf(coarse.current_hunger - fine.current_hunger) < 0.01, "Fome: independente da taxa de passos [S02]")

	var results := []
	for mult in [0.6, 1.0, 1.5, 2.0]:
		var h := _new_hunger()
		h.difficulty_multiplier = mult
		_simulate(h, 600.0, 10)
		results.append(snappedf(h.current_hunger, 0.01))
		h.free()
	_check(results == [94.0, 90.0, 85.0, 80.0], "Fome: presets 94 / 90 / 85 / 80 após 10 min [S03]", str(results))

	var inactive := _new_hunger()
	inactive.active = false
	_simulate(inactive, 600.0, 10)
	_check(is_equal_approx(inactive.current_hunger, 100.0), "Fome: inativa não diminui [S04/S05]")

	var floor_test := _new_hunger()
	floor_test.set_hunger(0.5)
	_simulate(floor_test, 120.0, 10)
	_check(floor_test.current_hunger == 0.0 and floor_test.is_starving(), "Fome: para em 0 e marca inanição")
	_check(is_equal_approx(floor_test.restore(200.0), 100.0) and floor_test.is_full(), "Fome: restaurar não passa de 100 [S07]")

	for n in [hunger, coarse, fine, inactive, floor_test]:
		n.free()


# ---------- comer ----------

func _test_food() -> void:
	var inv := _new_inventory()
	var hunger := _new_hunger()
	var health := _new_health()
	var food := FoodConsumer.new()
	food.inventory = inv
	food.hunger = hunger
	food.health = health
	inv.add_item(&"wild_berries", 3)

	hunger.set_hunger(50.0)
	_check(food.try_eat() == FoodConsumer.REASON_OK and is_equal_approx(hunger.current_hunger, 65.0) and inv.count(&"wild_berries") == 2, "Comer com fome 50: fome 65, uma fruta consumida [S06]")
	_check(food.try_eat() == FoodConsumer.REASON_COOLDOWN and inv.count(&"wild_berries") == 2, "Duas refeições em menos de 1 s: segunda recusada [S10]")
	food._physics_process(1.1)
	hunger.set_hunger(95.0)
	food.try_eat()
	_check(is_equal_approx(hunger.current_hunger, 100.0), "Comer com fome 95: limita em 100 [S07]")
	food._physics_process(1.1)
	var count_before := inv.count(&"wild_berries")
	_check(food.try_eat() == FoodConsumer.REASON_FULL and inv.count(&"wild_berries") == count_before, "Comer com fome 100: recusado, nada consumido [S08]")
	inv.remove_item(&"wild_berries", inv.count(&"wild_berries"))
	hunger.set_hunger(40.0)
	_check(food.try_eat() == FoodConsumer.REASON_NO_ITEM and is_equal_approx(hunger.current_hunger, 40.0), "Comer sem frutas: recusado, nada muda [S09]")
	inv.add_item(&"wood", 5)
	_check(food.try_eat() == FoodConsumer.REASON_NO_ITEM and inv.count(&"wood") == 5, "Madeira nunca é comida")
	inv.add_item(&"wild_berries", 1)
	health.apply_damage(DamageInfo.create(999.0, &"enemy:test"))
	_check(food.try_eat() == FoodConsumer.REASON_DEAD and inv.count(&"wild_berries") == 1, "Morto não come")
	for n in [inv, hunger, health, food]:
		n.free()


# ---------- inanição ----------

func _test_starvation() -> void:
	var hunger := _new_hunger()
	var health := _new_health()
	var starve := StarvationDamage.new()
	starve.hunger = hunger
	starve.health = health
	hunger.starving_started.connect(starve._reset_timer)
	hunger.starving_ended.connect(starve._reset_timer)
	health.died.connect(starve._on_died)
	health.revived.connect(starve._on_revived)

	var hits := [0]
	health.damaged.connect(func(info: DamageInfo):
		if info.cause == DamageInfo.CAUSE_STARVATION:
			hits[0] += 1)

	_simulate(starve, 30.0, 10)
	_check(hits[0] == 0, "Inanição: nenhum dano com fome acima de 0")
	hunger.set_hunger(0.0)
	_simulate(starve, 4.9, 10)
	_check(hits[0] == 0, "Inanição: sem dano antes de 5 s [S11]")
	_simulate(starve, 55.1, 10)
	_check(hits[0] == 12 and is_equal_approx(health.current_health, 76.0), "Inanição: 60 s = 12 tiques de 2 (24 de vida) [S12]", "tiques=%d vida=%.1f" % [hits[0], health.current_health])
	hunger.restore(15.0)
	_simulate(starve, 30.0, 10)
	_check(hits[0] == 12, "Inanição: comer para o dano [S13]")
	var causes := []
	health.died.connect(func(c): causes.append(c))
	hunger.set_hunger(0.0)
	_simulate(starve, 400.0, 10)
	_check(health.is_dead() and causes == [DamageInfo.CAUSE_STARVATION], "Inanição até a morte: died('starvation') uma vez [S14]")
	_check(not hunger.active, "Fome para enquanto o jogador está morto [S05]")
	health.revive(75.0)
	_check(hunger.active, "Fome volta a correr ao reviver")
	for n in [hunger, health, starve]:
		n.free()


# ---------- fonte de recurso ----------

func _test_resource_node() -> void:
	var node := (load(BERRY_BUSH) as PackedScene).instantiate() as ResourceNode
	root.add_child(node)
	var detector := InteractionDetector.new()
	detector.inventory = _new_inventory()
	_check(node.get_resource_category() == &"fruit" and node.collision_layer & 4 != 0 and node.collision_layer & 1 != 0, "Arbusto: categoria 'fruit', camadas world + resources")
	var result := node.interact(detector)
	_check(result.get("ok", false) and detector.inventory.count(&"wild_berries") == 2, "Coletar: +2 frutas no inventário")
	node.interact(detector)
	node.interact(detector)
	_check(node.is_depleted() and not node.can_interact(detector), "Esgota depois de 3 coletas")
	_check(not node.interact(detector).get("ok", true) and detector.inventory.count(&"wild_berries") == 6, "Esgotado não entrega nada")
	node.tick(node.regrow_time + 0.1)
	_check(not node.is_depleted() and node.harvests_left == node.max_harvests, "Volta depois do tempo de regeneração")

	var full := InteractionDetector.new()
	full.inventory = _new_inventory(1)
	full.inventory.add_item(&"wood", 50)
	var left := node.harvests_left
	_check(not node.interact(full).get("ok", true) and node.harvests_left == left and full.inventory.count(&"wild_berries") == 0, "Inventário cheio: coleta recusada sem gastar a fonte")
	for n in [detector.inventory, detector, full.inventory, full]:
		n.free()
	node.queue_free()


# ---------- integração na cena principal ----------

func _test_main_scene_integration() -> void:
	var main := _instantiate_main_isolated()
	root.add_child(main)
	await _wait_physics(3)
	var player := main.get_node("Player") as CharacterBody3D
	var detector := player.get_node_or_null("InteractionDetector") as InteractionDetector
	var health := player.get_node_or_null("Health") as HealthComponent
	var hunger := player.get_node_or_null("Hunger") as HungerComponent
	var inventory := player.get_node_or_null("Inventory") as Inventory
	var respawn := main.get_node_or_null("SimpleRespawn") as SimpleRespawn
	var hud := main.get_node_or_null("SurvivalHUD") as SurvivalHUD
	_check(detector != null and health != null and hunger != null and inventory != null and player.get_node_or_null("FoodConsumer") != null and player.get_node_or_null("StarvationDamage") != null, "Player tem os componentes de sobrevivência")
	_check(player is PlayerController and player.get_node_or_null("CameraPivot") is ThirdPersonCamera, "PlayerController e câmera da WLD-001 continuam no lugar")
	_check(respawn != null and hud != null and main.get_node_or_null("ResourceField") != null, "Cena principal tem respawn, HUD e campo de recursos")
	var field := main.get_node("ResourceField")
	var categories := {}
	for child in field.find_children("*", "ResourceNode", true, false):
		categories[(child as ResourceNode).category] = true
	_check(categories.has(&"wood") and categories.has(&"stone") and categories.has(&"fiber") and categories.has(&"fruit"), "Campo tem madeira, pedra, fibra e frutas")

	# Interação real pela física: perto de um arbusto e longe dele.
	var bush := field.get_node("BerryBushs/BerryBush01") as ResourceNode
	player.global_position = bush.global_position + Vector3(0, 0.1, 1.6)
	await _wait_physics(3)
	detector.refresh_focus()
	_check(detector.get_focused() == bush, "Detector encontra o arbusto a 1,6 m")
	_check(hud.get_prompt().contains("Colher") and hud.get_prompt().contains("[E]"), "HUD mostra o aviso '[E] Colher...'", hud.get_prompt())
	var result := detector.try_interact()
	_check(result.get("ok", false) and inventory.count(&"wild_berries") == 2, "Interagir coleta e adiciona ao inventário")
	_check(hud.get_inventory_text().contains("Frutas silvestres: 2"), "HUD atualiza o inventário", hud.get_inventory_text())
	player.global_position = bush.global_position + Vector3(0, 0.1, 4.0)
	await _wait_physics(3)
	detector.refresh_focus()
	_check(detector.get_focused() != bush, "Fora de 2,5 m o arbusto não é alvo [E14]")

	# Morte e respawn simples (valores do Intermediário, GDD 008).
	player.global_position = Vector3(10, 0.1, 10)
	await _wait_physics(2)
	inventory.add_item(&"stone", 4)
	health.apply_damage(DamageInfo.create(999.0, DamageInfo.CAUSE_STARVATION))
	await _wait_physics(2)
	_check(respawn.is_waiting() and not player.is_physics_processing() and not detector.enabled, "Morte: jogador e interação desativados")
	_check(hud.get_message().contains("fome"), "HUD informa morte por fome", hud.get_message())
	respawn.respawn_now()
	await _wait_physics(2)
	var spawn := main.get_node("SpawnPoint") as Node3D
	_check(player.global_position.distance_to(spawn.global_position) < 0.5, "Respawn no ponto inicial [DR08]")
	# A fome já volta a correr depois do respawn, então tolera a queda de poucos quadros.
	_check(is_equal_approx(health.current_health, 75.0) and absf(hunger.current_hunger - 50.0) < 0.01, "Respawn: vida 75% e fome 50% [DR12, Intermediário]", "vida=%.2f fome=%.4f" % [health.current_health, hunger.current_hunger])
	var bag := respawn.active_bag
	_check(inventory.get_all().is_empty() and bag != null and int(bag.contents.get(&"stone", 0)) == 4 and int(bag.contents.get(&"wild_berries", 0)) == 2, "Intermediário: itens vão para a mochila, inventário vazio [DR02]")
	_check(player.is_physics_processing() and detector.enabled and hunger.active, "Respawn: controles, interação e fome reativados")
	main.queue_free()
	await _wait_physics(1)


## Cena principal isolada do save do jogador: sem carregar nem gravar.
func _instantiate_main_isolated() -> Node:
	var scene_root := (load(MAIN_SCENE) as PackedScene).instantiate()
	var save := scene_root.get_node_or_null("SaveManager")
	if save != null:
		save.load_on_start = false
		save.autosave_interval = 0.0
		save.save_dir = "user://test_saves_isolated"
	var difficulty := scene_root.get_node_or_null("DifficultyManager")
	if difficulty != null:
		difficulty.ask_on_new_world = false
	return scene_root
