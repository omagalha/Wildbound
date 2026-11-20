extends SceneTree
## Testes do save base (WLD-019 parcial + WLD-027).
##
## Uso: godot --headless --path . --script res://tests/test_save.gd
## Grava numa pasta só de testes (user://test_saves_suite), nunca no save do jogo.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_suite"
const BASE := Vector3(-30, 0, 2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do save ==")
	_wipe_dir()
	await _test_roundtrip()
	await _test_backup_and_corruption()
	await _test_interrupted_and_tampered()
	await _test_guards()
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


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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
	var pieces := (world.get_node("BuildingManager") as BuildingManager).get_pieces()
	return pieces[pieces.size() - 1]


# ---------- testes ----------

func _test_roundtrip() -> void:
	var world := await _new_world()
	var save := world.get_node("SaveManager") as SaveManager
	_check(await save.load_game() == SaveManager.STATUS_NO_SAVE, "Sem arquivo: status 'no_save', jogo começa do zero")

	var player := world.get_node("Player") as CharacterBody3D
	var inventory := player.get_node("Inventory") as Inventory
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	await _wait(2)
	(world.get_node("Progression/Experience") as ExperienceComponent).restore({"total_xp": 700})
	inventory.add_item(&"wood", 60)
	inventory.add_item(&"fiber", 40)
	inventory.add_item(&"wild_berries", 7)
	var foundation := await _place(world, 0, BASE)
	var wall := await _place(world, 1, BASE + Vector3(0, 0, -1.5))
	var bed := await _place(world, 5, BASE + Vector3(-2.5, 0, 2.5)) as SurvivalBed
	bed.interact(player.get_node("InteractionDetector"))
	var bush := world.get_node("ResourceField/BerryBushs/BerryBush02") as ResourceNode
	bush.interact(player.get_node("InteractionDetector"))
	(player.get_node("Hunger") as HungerComponent).set_hunger(42.5)
	(player.get_node("Health") as HealthComponent).apply_damage(DamageInfo.create(20.0, &"enemy:test"))
	var position := BASE + Vector3(1.0, 0.1, 4.0)
	player.global_position = position
	var expected_inventory := inventory.get_all()
	var wall_transform := wall.global_transform
	var wall_id := wall.piece_id
	var foundation_id := foundation.piece_id
	var bed_id := bed.piece_id

	_check(save.save_game(), "Salvar devolve sucesso")
	_check(FileAccess.file_exists(save.main_path()) and not FileAccess.file_exists(save.tmp_path()), "Arquivo gravado; nenhum .tmp sobrando")
	_check(not save.parse_document(FileAccess.get_file_as_string(save.main_path())).is_empty(), "Arquivo gravado passa na validação (versão + soma de verificação)")
	await _free_world(world)

	world = await _new_world()
	save = world.get_node("SaveManager") as SaveManager
	player = world.get_node("Player") as CharacterBody3D
	inventory = player.get_node("Inventory") as Inventory
	var manager := world.get_node("BuildingManager") as BuildingManager
	_check(await save.load_game() == SaveManager.STATUS_LOADED, "Carregar: status 'loaded'")
	_check(inventory.get_all() == expected_inventory, "Inventário restaurado igual [D10]", str(inventory.get_all()))
	_check(manager.get_pieces().size() == 3, "3 peças restauradas [BL10]")
	var restored_wall := manager.get_piece(wall_id)
	_check(restored_wall != null and restored_wall.global_transform.is_equal_approx(wall_transform), "Posição e rotação da parede preservadas [BL10]")
	_check(restored_wall != null and restored_wall.support_id == foundation_id, "Conexão parede → fundação preservada [BL10]")
	var respawn := world.get_node("SimpleRespawn") as SimpleRespawn
	_check(respawn.active_bed != null and respawn.active_bed.piece_id == bed_id, "Leito ativo restaurado como ponto de retorno [DR05]")
	var restored_bush := world.get_node("ResourceField/BerryBushs/BerryBush02") as ResourceNode
	_check(restored_bush.harvests_left == restored_bush.max_harvests - 1, "Estado da fonte de recurso restaurado")
	_check(player.global_position.distance_to(position) < 0.05, "Posição do jogador restaurada", str(player.global_position))
	_check(is_equal_approx((player.get_node("Health") as HealthComponent).current_health, 80.0) and absf((player.get_node("Hunger") as HungerComponent).current_hunger - 42.5) < 0.05, "Vida e fome restauradas")
	var refund := manager.refund_for(restored_wall)
	_check(int(refund[&"wood"]) == 4, "Depois de carregar, a devolução é 75% (a janela de 10 s não sobrevive) [BL19]")
	var new_piece := await _place(world, 0, BASE + Vector3(3, 0, 0))
	_check(new_piece != null and manager.get_pieces().size() == 4 and not new_piece.piece_id in [foundation_id, wall_id, bed_id], "Peça nova depois de carregar não repete id")
	await _free_world(world)


func _test_backup_and_corruption() -> void:
	var world := await _new_world()
	var save := world.get_node("SaveManager") as SaveManager
	var inventory := world.get_node("Player/Inventory") as Inventory
	await save.load_game()
	var stone_before := inventory.count(&"stone")
	inventory.add_item(&"stone", 5)
	_check(save.save_game() and FileAccess.file_exists(save.bak_path()), "Segundo save cria a cópia de segurança .bak")
	_write(save.main_path(), "{lixo corrompido")
	await _free_world(world)

	world = await _new_world()
	save = world.get_node("SaveManager") as SaveManager
	inventory = world.get_node("Player/Inventory") as Inventory
	_check(await save.load_game() == SaveManager.STATUS_LOADED and inventory.count(&"stone") == stone_before, "Atual corrompido: carrega a cópia de segurança [HC09]")
	_check(save.save_game() and FileAccess.file_exists(save.main_path() + ".corrupt") and not save.parse_document(FileAccess.get_file_as_string(save.bak_path())).is_empty(), "Novo save não transforma o corrompido em cópia de segurança (guarda como .corrupt)")
	_write(save.main_path(), "x")
	_write(save.bak_path(), "y")
	await _free_world(world)

	world = await _new_world()
	save = world.get_node("SaveManager") as SaveManager
	inventory = world.get_node("Player/Inventory") as Inventory
	_check(await save.load_game() == SaveManager.STATUS_CORRUPTED and inventory.get_all().is_empty(), "Atual e cópia corrompidos: status 'corrupted', jogo do zero, nada aplicado [HC09]")
	_check(FileAccess.file_exists(save.main_path()) and FileAccess.file_exists(save.bak_path()), "Arquivos corrompidos não são apagados (diagnóstico)")
	await _free_world(world)
	_wipe_dir()


func _test_interrupted_and_tampered() -> void:
	var world := await _new_world()
	var save := world.get_node("SaveManager") as SaveManager
	var inventory := world.get_node("Player/Inventory") as Inventory
	inventory.add_item(&"fiber", 9)
	save.save_game()
	# Simula queda de energia entre "atual → .bak" e ".tmp → atual".
	DirAccess.rename_absolute(save.main_path(), save.tmp_path())
	await _free_world(world)

	world = await _new_world()
	save = world.get_node("SaveManager") as SaveManager
	inventory = world.get_node("Player/Inventory") as Inventory
	_check(await save.load_game() == SaveManager.STATUS_LOADED and inventory.count(&"fiber") == 9, "Gravação interrompida: o .tmp válido é carregado [HC04]")
	_check(FileAccess.file_exists(save.main_path()) and not FileAccess.file_exists(save.tmp_path()), "O .tmp válido é promovido a arquivo atual")

	var text := FileAccess.get_file_as_string(save.main_path())
	var document: Dictionary = JSON.parse_string(text)
	var original_payload := String(document["payload"])
	var fiber_at := original_payload.find("\"fiber\"")
	var digit_at := original_payload.find("9", fiber_at)
	document["payload"] = original_payload.substr(0, digit_at) + "8" + original_payload.substr(digit_at + 1)
	_check(fiber_at >= 0 and document["payload"] != original_payload, "(preparação) quantidade de fibra alterada no conteúdo")
	_check(save.parse_document(JSON.stringify(document)).is_empty(), "Conteúdo alterado sem atualizar a soma de verificação é rejeitado")
	document = JSON.parse_string(text)
	document["format_version"] = 99
	_check(save.parse_document(JSON.stringify(document)).is_empty(), "Versão de formato desconhecida é rejeitada")
	await _free_world(world)
	_wipe_dir()


func _test_guards() -> void:
	var world := await _new_world()
	var save := world.get_node("SaveManager") as SaveManager
	var health := world.get_node("Player/Health") as HealthComponent
	var player := world.get_node("Player") as CharacterBody3D

	health.apply_damage(DamageInfo.create(999.0, &"enemy:test"))
	_check(not save.save_game() and not FileAccess.file_exists(save.main_path()), "Morto aguardando respawn: não grava")
	(world.get_node("SimpleRespawn") as SimpleRespawn).respawn_now()
	await _wait(1)
	player.set_physics_process(false)

	var state := save.collect_state()
	state["player"]["position"] = [0.0, -200.0, 0.0]
	save.apply_state(state)  # sem await: verifica o estado no meio do carregamento
	_check(not health.accepts_damage and save.is_loading(), "Durante o carregamento: sem dano [HC12]")
	while save.is_loading():
		await physics_frame
	var spawn := world.get_node("SpawnPoint") as Node3D
	_check(player.global_position.distance_to(spawn.global_position) < 0.5, "Posição salva sem chão: jogador vai ao ponto inicial [HC14]")
	_check(health.accepts_damage and not save.is_loading(), "Depois de carregar, dano volta a valer")

	state = save.collect_state()
	state["building"] = {"pieces": [{"id": "piece_7", "definition": "conteudo_removido", "transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], "support": ""}], "active_bed": ""}
	await save.apply_state(state)
	_check((world.get_node("BuildingManager") as BuildingManager).get_pieces().is_empty(), "Peça de definição desconhecida é ignorada sem travar")

	save.autosave_interval = 60.0
	save._autosave_left = 60.0
	save._physics_process(61.0)
	_check(FileAccess.file_exists(save.main_path()), "Autosave grava depois de 60 s de jogo")
	await _free_world(world)
