extends SceneTree
## Testes de dificuldade (WLD-018), morte com mochila (WLD-020/021) e progressão (WLD-023/024).
##
## Uso: godot --headless --path . --script res://tests/test_progression.gd
## Grava numa pasta só de testes (user://test_saves_progression).

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_progression"
const BASE := Vector3(-30, 0, 2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de dificuldade, mochila e progressão ==")
	_wipe_dir()
	await _test_curve_and_rules()
	await _test_difficulty()
	await _test_difficulty_select()
	await _test_bag()
	await _test_progression_in_game()
	await _test_build_lock()
	await _test_save_roundtrip()
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


func _new_world(ask: bool = false) -> Node:
	var world := (load(MAIN_SCENE) as PackedScene).instantiate()
	var save := world.get_node("SaveManager") as SaveManager
	save.load_on_start = false
	save.autosave_interval = 0.0
	save.save_dir = TEST_DIR
	(world.get_node("DifficultyManager") as DifficultyManager).ask_on_new_world = ask
	root.add_child(world)
	await _wait(3)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	return world


func _free_world(world: Node) -> void:
	paused = false
	world.queue_free()
	await _wait(2)


func _kill(world: Node) -> void:
	var health := world.get_node("Player/Health") as HealthComponent
	health.apply_damage(DamageInfo.create(health.max_health + 10.0, &"enemy:test"))
	await _wait(1)


# ---------- curva e regras (sem cena) ----------

func _test_curve_and_rules() -> void:
	print("-- Curva de níveis e regras de XP --")
	var curve := load("res://resources/progression/mvp_level_curve.tres") as LevelCurve
	_check(curve.xp_for_level(1) == 0 and curve.xp_for_level(2) == 100 and curve.xp_for_level(3) == 250 and curve.xp_for_level(4) == 450 and curve.xp_for_level(5) == 700, "XP acumulado 0/100/250/450/700 [PG01]")
	_check(curve.level_for_xp(99) == 1 and curve.level_for_xp(100) == 2 and curve.level_for_xp(449) == 3 and curve.level_for_xp(10000) == 5, "Nível pelo XP respeita limites e o máximo 5 [PG02]")
	_check(curve.level_unlocking(&"knowledge_primitive_shelter") == 2 and curve.level_unlocking(&"knowledge_survival_bed") == 3, "Abrigo no nível 2, leito no nível 3")
	_check(curve.level_name(1) == "Sobrevivente" and curve.level_name(5) == "Pioneiro", "Nomes dos níveis do MVP")

	var catalog := load("res://resources/building/building_catalog.tres") as BuildingCatalog
	var all_known := true
	for piece in catalog.pieces:
		if curve.level_unlocking(piece.required_knowledge) <= 0:
			all_known = false
	_check(all_known, "Toda peça de construção pede um conhecimento liberado por algum nível")

	var knowledge := KnowledgeManager.new()
	_check(knowledge.is_known(&""), "Requisito vazio conta como conhecido")
	_check(knowledge.learn(&"k_a") and not knowledge.learn(&"k_a") and knowledge.get_all().size() == 1, "Conhecimento não duplica [KN02]")
	knowledge.restore({"k_b": "manual"})
	_check(knowledge.is_known(&"k_a") and knowledge.is_known(&"k_b"), "Restaurar une com o que já se sabe")
	knowledge.free()

	var xp := ExperienceComponent.new()
	xp.rules = load("res://resources/progression/mvp_xp_rules.tres") as XPRules
	_check(xp.award_collect(&"wood", 15) == 15 and xp.award_collect(&"wood", 15) == 5 and xp.award_collect(&"wood", 3) == 0, "Coleta limitada a 20 XP por tipo na janela [PG05]")
	_check(xp.award_collect(&"stone", 4) == 4, "Limite é por tipo de item")
	xp.game_time = 601.0
	_check(xp.award_collect(&"wood", 3) == 3, "Janela de 10 min reabre o limite")
	_check(xp.award_first(&"structure", &"wall", 30) == 30 and xp.award_first(&"structure", &"wall", 30) == 0, "Marco de primeira construção conta uma vez [PG06]")
	_check(xp.total_xp == 57, "Total de XP somado corretamente", str(xp.total_xp))
	xp.free()


# ---------- dificuldade ----------

func _test_difficulty() -> void:
	print("-- Dificuldade --")
	var world := await _new_world()
	var manager := world.get_node("DifficultyManager") as DifficultyManager
	var hunger := world.get_node("Player/Hunger") as HungerComponent
	var respawn := world.get_node("SimpleRespawn") as SimpleRespawn
	var bush := world.get_node("ResourceField/BerryBushs/BerryBush01") as ResourceNode
	_check(manager.current != null and manager.current.id == &"intermediate", "Sem escolha, o mundo começa no Intermediário")
	_check(is_equal_approx(hunger.difficulty_multiplier, 1.0) and respawn.death_rules != null and respawn.death_rules.drop_carried_items, "Intermediário: fome ×1, itens caem na mochila")
	_check(not manager.is_chosen(), "Aplicar o padrão não conta como escolha")

	_check(manager.choose(&"easy"), "Escolher Fácil")
	_check(is_equal_approx(hunger.difficulty_multiplier, 0.6) and not respawn.death_rules.drop_carried_items and is_equal_approx(bush.yield_multiplier, 1.3), "Fácil: fome ×0,6, sem perda de itens, recursos ×1,3 [DF03]")
	_check(not manager.choose(&"hard") and manager.current.id == &"easy", "Preset não muda depois de escolhido [DF05]")
	_check(FileAccess.file_exists(TEST_DIR + "/world.json"), "Escolha grava o mundo imediatamente")
	_check(manager.get_save_data()["preset_id"] == "easy", "Dados de save guardam o preset")
	await _free_world(world)

	world = await _new_world()
	manager = world.get_node("DifficultyManager") as DifficultyManager
	_check(not manager.choose(&"nao_existe") and manager.current.id == &"intermediate", "Preset inexistente é recusado")
	manager.restore(&"nao_existe")
	_check(manager.current.id == &"intermediate" and manager.is_chosen(), "Restaurar preset desconhecido cai no padrão")
	await _free_world(world)

	# Rendimento da coleta com multiplicador fracionário
	var node := ResourceNode.new()
	node.amount_per_harvest = 2
	node.yield_multiplier = 1.3
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	node.rng = rng
	var total := 0
	var minimum := 99
	for i in 1000:
		var amount := node.roll_amount()
		total += amount
		minimum = mini(minimum, amount)
	_check(minimum >= 2 and absf(total / 1000.0 - 2.6) < 0.1, "Arredondamento probabilístico: média ≈ 2,6 com base 2 × 1,3", str(total / 1000.0))
	node.yield_multiplier = 0.1
	_check(node.roll_amount() >= 1, "Coleta nunca rende zero")
	node.free()
	_wipe_dir()


func _test_difficulty_select() -> void:
	print("-- Tela de escolha --")
	var world := await _new_world(true)
	var save := world.get_node("SaveManager") as SaveManager
	var select := world.get_node("DifficultySelect") as DifficultySelect
	var manager := world.get_node("DifficultyManager") as DifficultyManager
	_check(await save.load_game() == SaveManager.STATUS_NO_SAVE, "Mundo novo, sem save")
	_check(select.is_open() and paused, "Mundo novo abre a escolha e pausa o jogo [DF01]")
	select._choose(&"hard")
	_check(not select.is_open() and not paused and manager.current.id == &"hard", "Escolher fecha a tela, despausa e aplica Difícil")
	await _free_world(world)
	world = await _new_world(true)
	save = world.get_node("SaveManager") as SaveManager
	select = world.get_node("DifficultySelect") as DifficultySelect
	manager = world.get_node("DifficultyManager") as DifficultyManager
	_check(await save.load_game() == SaveManager.STATUS_LOADED and not select.is_open() and manager.current.id == &"hard", "Mundo salvo não pergunta de novo e mantém Difícil")
	await _free_world(world)
	_wipe_dir()


# ---------- morte e mochila ----------

func _test_bag() -> void:
	print("-- Morte e mochila --")
	var world := await _new_world()
	var respawn := world.get_node("SimpleRespawn") as SimpleRespawn
	var inventory := world.get_node("Player/Inventory") as Inventory
	var player := world.get_node("Player") as CharacterBody3D
	var health := world.get_node("Player/Health") as HealthComponent
	var hunger := world.get_node("Player/Hunger") as HungerComponent
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var safe := Vector3(5, 0.1, 5)
	respawn.last_safe_position = safe
	inventory.add_item(&"wood", 30)
	inventory.add_item(&"stone", 7)
	await _kill(world)
	var bag := respawn.active_bag
	_check(bag != null and inventory.get_all().is_empty(), "Intermediário: morrer move tudo para a mochila [DR02]")
	_check(bag != null and bag.contents.get(&"wood", 0) == 30 and bag.contents.get(&"stone", 0) == 7 and bag.total_items() == 37, "Mochila guarda exatamente o que havia")
	_check(bag != null and bag.global_position.is_equal_approx(safe), "Mochila fica na última posição segura [DR05]")
	respawn.respawn_now()
	_check(is_equal_approx(health.current_health, health.max_health * 0.75) and is_equal_approx(hunger.current_hunger, hunger.max_hunger * 0.5), "Respawn no Intermediário: vida 75%, fome 50%")

	# Segunda morte sem recuperar: itens unidos, nada se perde
	inventory.add_item(&"fiber", 4)
	await _kill(world)
	var second := respawn.active_bag
	_check(second != null and second != bag and second.total_items() == 41 and second.contents.get(&"fiber", 0) == 4, "Segunda morte une a mochila anterior à nova [DR13]")
	await _wait(1)
	_check(not is_instance_valid(bag), "Mochila antiga removida do mundo")
	respawn.respawn_now()
	_check(second.get_interaction_prompt().contains("41"), "Prompt mostra quantos itens restam")

	# Recuperação parcial com inventário quase cheio
	inventory.capacity = 1
	var result := second.interact(detector)
	_check(result["ok"] and inventory.used_slots() == 1 and second.total_items() > 0 and is_instance_valid(second), "Inventário cheio: recupera o que cabe, o resto fica na mochila")
	var before := second.total_items()
	inventory.capacity = 20
	result = second.interact(detector)
	await _wait(1)
	_check(result["ok"] and inventory.count(&"wood") == 30 and inventory.count(&"stone") == 7 and inventory.count(&"fiber") == 4, "Recuperar devolve todos os itens", str(inventory.get_all()) + " antes=" + str(before))
	_check(respawn.active_bag == null and not is_instance_valid(second), "Mochila vazia some e deixa de ser a ativa")

	# Fácil: sem perda de itens
	var manager := world.get_node("DifficultyManager") as DifficultyManager
	manager.apply(manager.get_preset(&"easy"))
	await _kill(world)
	_check(respawn.active_bag == null and inventory.count(&"wood") == 30, "Fácil: morrer não cria mochila nem tira itens")
	respawn.respawn_now()
	_check(is_equal_approx(health.current_health, health.max_health) and is_equal_approx(hunger.current_hunger, hunger.max_hunger * 0.75), "Respawn no Fácil: vida 100%, fome 75%")

	# Inventário vazio no Intermediário não cria mochila vazia
	manager.apply(manager.get_preset(&"intermediate"))
	inventory.load_counts({})
	await _kill(world)
	_check(respawn.active_bag == null, "Morrer sem itens não cria mochila vazia")
	respawn.respawn_now()

	# Posição segura só é registrada vivo
	player.global_position = Vector3(9, 50, 9)
	respawn.record_safe_position()
	_check(not respawn.last_safe_position.is_equal_approx(Vector3(9, 50, 9)), "Posição no ar não vira posição segura")
	await _free_world(world)


# ---------- progressão no jogo ----------

func _test_progression_in_game() -> void:
	print("-- Progressão no jogo --")
	var world := await _new_world()
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var levels := world.get_node("Progression/LevelManager") as LevelManager
	var knowledge := world.get_node("Progression/Knowledge") as KnowledgeManager
	var inventory := world.get_node("Player/Inventory") as Inventory
	var hud := world.get_node("LevelHUD") as LevelHUD
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	_check(levels.level == 1 and knowledge.is_known(&"knowledge_campfire") and not knowledge.is_known(&"knowledge_primitive_shelter"), "Começa no nível 1 sabendo só a fogueira e o vínculo inicial")
	_check(hud.get_level_text().begins_with("Nível 1 — Sobrevivente"), "HUD mostra nível 1", hud.get_level_text())

	var ups := []
	levels.level_up.connect(func(l, _n, u): ups.append([l, u]))
	var tree := world.get_node("ResourceField/DeadTrees/DeadTree01") as ResourceNode
	var result := tree.interact(detector)
	detector.interacted.emit(tree, result)
	_check(experience.total_xp == int(result["amount"]), "Coletar dá 1 XP por unidade", str(experience.total_xp))

	experience.award_first(&"discovery", &"test_place", 99 - experience.total_xp)
	_check(levels.level == 1 and ups.is_empty(), "99 XP ainda é nível 1")
	experience.award_first(&"discovery", &"test_place_2", 1)
	_check(levels.level == 2 and ups.size() == 1 and ups[0][1].has(&"knowledge_primitive_shelter"), "100 XP: nível 2 libera Abrigo Primitivo [PG03]")
	_check(hud.get_notice().contains("Nível 2"), "Aviso de subida de nível aparece no HUD", hud.get_notice())

	experience.award_first(&"challenge", &"big", 600)
	_check(levels.level == 5 and ups.size() == 4, "Salto de XP passa por todos os níveis, um aviso por nível", str(ups.size()))
	_check(knowledge.is_known(&"knowledge_gathering_capacity") and inventory.capacity == 25, "Nível 4: capacidade do inventário +5 [PG07]")
	_check(levels.is_max_level() and hud.get_level_text().contains("máximo"), "Nível 5 é o máximo do MVP")
	experience.award_first(&"challenge", &"more", 500)
	_check(levels.level == 5, "XP extra não passa do nível máximo")
	await _free_world(world)


func _test_build_lock() -> void:
	print("-- Construção bloqueada por nível --")
	var world := await _new_world()
	var controller := world.get_node("PlacementController") as PlacementController
	var inventory := world.get_node("Player/Inventory") as Inventory
	var player := world.get_node("Player") as CharacterBody3D
	var manager := world.get_node("BuildingManager") as BuildingManager
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	await _wait(2)
	inventory.add_item(&"wood", 40)
	inventory.add_item(&"fiber", 30)
	inventory.add_item(&"stone", 10)
	controller.enter()
	controller.select(0)  # fundação
	var eval := controller.evaluate(controller.catalog.pieces[controller.selected_index], BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(eval["state"] == PlacementController.State.MISSING_RESOURCES and String(eval["reason"]).contains("nível 2"), "Nível 1: fundação bloqueada com 'Requer nível 2'", str(eval.get("reason")))
	controller.update_preview(BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(not controller.confirm() and manager.get_pieces().is_empty() and inventory.count(&"wood") == 40, "Confirmar peça bloqueada não constrói nem gasta")
	controller.select(4)  # fogueira
	eval = controller.evaluate(controller.catalog.pieces[controller.selected_index], BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(eval["state"] == PlacementController.State.VALID, "Fogueira já liberada no nível 1", str(eval.get("reason")))
	var hud := world.get_node("BuildingHUD")
	_check(hud.get_pieces_text().contains("🔒"), "HUD de construção marca peças bloqueadas")

	experience.restore({"total_xp": 0})
	experience.award_first(&"challenge", &"lvl2", 100)
	controller.select(0)
	eval = controller.evaluate(controller.catalog.pieces[controller.selected_index], BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(eval["state"] == PlacementController.State.VALID, "Ao chegar no nível 2 a fundação libera", str(eval.get("reason")))
	controller.update_preview(BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(controller.confirm(), "Fundação construída no nível 2")
	await _wait(2)
	_check(experience.has_first(&"structure", &"building_foundation_primitive") and experience.total_xp == 130, "Primeira fundação dá 30 XP", str(experience.total_xp))
	controller.select(5)  # leito
	eval = controller.evaluate(controller.catalog.pieces[controller.selected_index], BASE + Vector3.UP * 12.0, Vector3.DOWN)
	_check(eval["state"] == PlacementController.State.MISSING_RESOURCES and String(eval["reason"]).contains("nível 3"), "Leito ainda pede nível 3")
	await _free_world(world)


# ---------- save ----------

func _test_save_roundtrip() -> void:
	print("-- Save de dificuldade, progressão e mochila --")
	_wipe_dir()
	var world := await _new_world()
	var manager := world.get_node("DifficultyManager") as DifficultyManager
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var knowledge := world.get_node("Progression/Knowledge") as KnowledgeManager
	var respawn := world.get_node("SimpleRespawn") as SimpleRespawn
	var inventory := world.get_node("Player/Inventory") as Inventory
	var save := world.get_node("SaveManager") as SaveManager
	manager.choose(&"hard")
	experience.award_first(&"challenge", &"x", 460)  # nível 4: capacidade 25
	experience.award_first(&"structure", &"building_wall_primitive", 30)
	knowledge.learn(&"knowledge_from_scroll", &"manual")
	for i in 22:
		inventory.add_item([&"wood", &"stone", &"fiber"][i % 3], 50)
	_check(inventory.used_slots() == 22, "22 pilhas só cabem com a capacidade do nível 4")
	var saved_inventory := inventory.get_all()
	respawn.last_safe_position = Vector3(3, 0.1, -4)
	var bag := respawn.drop_inventory_into_bag(respawn.last_safe_position)
	inventory.load_counts(saved_inventory)
	_check(save.save_game(), "Salvar com mochila no mundo")
	var bag_items := bag.contents.duplicate()
	await _free_world(world)

	world = await _new_world()
	manager = world.get_node("DifficultyManager") as DifficultyManager
	experience = world.get_node("Progression/Experience") as ExperienceComponent
	knowledge = world.get_node("Progression/Knowledge") as KnowledgeManager
	respawn = world.get_node("SimpleRespawn") as SimpleRespawn
	inventory = world.get_node("Player/Inventory") as Inventory
	save = world.get_node("SaveManager") as SaveManager
	var levels := world.get_node("Progression/LevelManager") as LevelManager
	var ups := []
	levels.level_up.connect(func(l, _n, _u): ups.append(l))
	_check(await save.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	_check(manager.current.id == &"hard" and is_equal_approx((world.get_node("Player/Hunger") as HungerComponent).difficulty_multiplier, 1.5), "Preset Difícil restaurado e aplicado")
	_check(experience.total_xp == 490 and levels.level == 4, "XP e nível restaurados", "%d / %d" % [experience.total_xp, levels.level])
	_check(ups.is_empty(), "Carregar não dispara aviso de subida de nível")
	_check(experience.has_first(&"structure", &"building_wall_primitive"), "Marcos de primeira vez restaurados (não pagam de novo)")
	_check(knowledge.is_known(&"knowledge_from_scroll") and knowledge.is_known(&"knowledge_survival_bed"), "Conhecimentos restaurados, inclusive os fora da curva")
	_check(inventory.used_slots() == 22 and inventory.get_all() == saved_inventory, "Inventário de 22 pilhas restaurado (capacidade aplicada antes)", str(inventory.used_slots()))
	var restored := respawn.active_bag
	_check(restored != null and restored.contents == bag_items and restored.global_position.is_equal_approx(Vector3(3, 0.1, -4)), "Mochila restaurada com itens e posição")
	await _free_world(world)
	_wipe_dir()
