extends SceneTree
## Testes da construção híbrida (WLD-025/026, BUILDING.md).
##
## Uso: godot --headless --path . --script res://tests/test_building.gd
## Os ids entre colchetes ([BL02], [DR09]...) apontam para docs/systems/.
##
## A mira é simulada com um raio vertical de cima para baixo sobre o ponto
## desejado, o que torna o resultado determinístico.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const BASE := Vector3(-30, 0, 2)  # área livre do mundo de teste

var _passed := 0
var _failed := 0
var main: Node
var player: CharacterBody3D
var controller: PlacementController
var manager: BuildingManager
var inventory: Inventory
var respawn: SimpleRespawn
var health: HealthComponent
var hud: BuildingHUD

const S_VALID := PlacementController.State.VALID
const S_INVALID := PlacementController.State.INVALID
const S_MISSING := PlacementController.State.MISSING_RESOURCES
const FOUNDATION := 0
const WALL := 1
const DOORWAY := 2
const ROOF := 3
const CAMPFIRE := 4
const BED := 5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de construção ==")
	_test_input_map()
	await _setup()
	await _test_resources_and_preview()
	await _test_foundation_and_walls()
	await _test_roof()
	await _test_rules()
	await _test_free_objects()
	await _test_removal()
	await _test_bed_respawn()
	await _test_mode_rules()
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


func _wait_physics(frames: int = 2) -> void:
	for i in frames:
		await physics_frame


func _aim(target: Vector3) -> int:
	return controller.update_preview(target + Vector3.UP * 12.0, Vector3.DOWN)


func _place(index: int, target: Vector3) -> BuildingPiece:
	controller.select(index)
	var state := _aim(target)
	if state != S_VALID:
		print("      (prévia: %s)" % controller.last_reason)
		return null
	var before := manager.get_pieces().size()
	controller.confirm()
	await _wait_physics(2)
	var pieces := manager.get_pieces()
	return pieces[pieces.size() - 1] if pieces.size() > before else null


func _give(wood: int, fiber: int, stone: int = 0) -> void:
	inventory.load_counts({})
	if wood > 0: inventory.add_item(&"wood", wood)
	if fiber > 0: inventory.add_item(&"fiber", fiber)
	if stone > 0: inventory.add_item(&"stone", stone)


func _clear_pieces() -> void:
	manager.clear_all()
	await _wait_physics(2)


## Madeira total = inventário + custo das peças existentes. Nunca pode aumentar.
func _wood_total() -> int:
	var total := inventory.count(&"wood")
	for piece in manager.get_pieces():
		total += int(piece.definition.cost.get(&"wood", 0))
	return total


# ---------- testes ----------

func _test_input_map() -> void:
	var expected := {&"build_mode": KEY_B, &"build_rotate": KEY_R, &"build_remove": KEY_X, &"build_piece_1": KEY_1, &"build_piece_6": KEY_6}
	for action in expected:
		var ok := false
		if InputMap.has_action(action):
			for ev in InputMap.action_get_events(action):
				ok = ok or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == expected[action])
		_check(ok, "InputMap: '%s' -> %s" % [action, OS.get_keycode_string(expected[action])])
	var mouse_ok := InputMap.has_action(&"build_confirm") and InputMap.has_action(&"build_cancel") and InputMap.has_action(&"build_cycle_snap")
	_check(mouse_ok, "InputMap: confirmar, cancelar e alternar encaixe no mouse")


func _setup() -> void:
	main = _instantiate_main_isolated()
	root.add_child(main)
	await _wait_physics(3)
	player = main.get_node("Player")
	controller = main.get_node("PlacementController")
	manager = main.get_node("BuildingManager")
	inventory = player.get_node("Inventory")
	respawn = main.get_node("SimpleRespawn")
	health = player.get_node("Health")
	hud = main.get_node("BuildingHUD")
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	player.set_physics_process(false)  # parado, para as posições não mudarem
	# Os testes de construção partem do nível máximo do MVP (todas as peças liberadas).
	(main.get_node("Progression/Experience") as ExperienceComponent).restore({"total_xp": 700})
	await _wait_physics(3)
	_check(controller.catalog.pieces.size() == 9, "Catálogo com 9 peças (inclui fornalha, baú e braseiro)")
	var order := main.get_children().map(func(n): return n.name)
	_check(order.find(&"PlacementController") > order.find(&"Player"), "Controle de construção depois do Player: recebe o Esc antes da câmera [R-BL-03]")


func _test_resources_and_preview() -> void:
	_give(0, 0)
	_check(controller.enter() and controller.active and hud.is_panel_visible(), "B entra no modo de construção e mostra o painel")
	controller.select(FOUNDATION)
	_check(_aim(BASE) == S_MISSING and controller.last_reason.contains("Faltam"), "Sem recursos: estado amarelo com o que falta [BL07]", controller.last_reason)
	_check(hud.get_status_text().begins_with("! "), "HUD: estado amarelo com ícone '!', não só cor", hud.get_status_text())
	_give(100, 50, 10)
	_check(_aim(BASE) == S_VALID and hud.get_status_text().begins_with("✓ "), "Com recursos: fundação válida, HUD com '✓'")
	_check(inventory.count(&"wood") == 100, "Prévia não consome recursos [BL06]")
	controller.exit()
	controller.enter()
	_check(inventory.count(&"wood") == 100, "Cancelar não consome recursos [BL06]")


func _test_foundation_and_walls() -> void:
	var foundation := await _place(FOUNDATION, BASE)
	_check(foundation != null and foundation.global_position.distance_to(BASE) < 0.01, "Fundação colocada em terreno válido [BL01]")
	_check(inventory.count(&"wood") == 92 and inventory.count(&"fiber") == 46, "Fundação consome exatamente 8 madeira e 4 fibra")
	_check(foundation != null and foundation.collision_layer & 1 != 0, "Peça na camada 'world': jogador e câmera colidem")

	var north := await _place(WALL, BASE + Vector3(0, 0, -1.5))
	_check(north != null and north.global_position.distance_to(BASE + Vector3(0, 0.3, -1.5)) < 0.01, "Parede encaixa na borda norte, sobre a fundação [BL02]")
	_check(north != null and north.support_id == foundation.piece_id, "Parede registra a fundação como suporte")
	var east := await _place(WALL, BASE + Vector3(1.5, 0, 0))
	_check(east != null and absf(absf(east.global_transform.basis.x.dot(Vector3.BACK)) - 1.0) < 0.01, "Parede na borda leste gira 90° automaticamente (fica ao longo da borda) [BL02]")
	var door := await _place(DOORWAY, BASE + Vector3(0, 0, 1.5))
	_check(door != null, "Entrada sem porta encaixa na borda sul [P-BL-01]")
	controller.select(WALL)
	_check(_aim(BASE + Vector3(0, 0, -1.5)) == S_INVALID, "Encaixe ocupado não aceita outra peça [BL27]", controller.last_reason)
	_check(_aim(BASE + Vector3(-1.5, 0, 5)) == S_INVALID and controller.last_reason.contains("encaixe"), "Parede sem encaixe por perto é inválida")

	var neighbor := await _place(FOUNDATION, BASE + Vector3(0, 0, -3))
	_check(neighbor != null and neighbor.global_position.distance_to(BASE + Vector3(0, 0, -3)) < 0.01 and neighbor.support_id == &"", "Fundação vizinha encaixa a 3 m e se apoia no chão, não na outra")


func _test_roof() -> void:
	var neighbor := manager.get_pieces().filter(func(p): return p.global_position.distance_to(BASE + Vector3(0, 0, -3)) < 0.01)[0] as BuildingPiece
	controller.select(ROOF)
	_check(_aim(neighbor.global_position) == S_INVALID and controller.last_reason.contains("parede"), "Telhado sem parede é recusado [BL14]", controller.last_reason)
	var roof := await _place(ROOF, BASE)
	_check(roof != null and absf(roof.global_position.y - 3.3) < 0.01, "Telhado encaixa no topo de uma fundação com parede [BL03]")


func _test_rules() -> void:
	controller.select(FOUNDATION)
	_check(_aim(BASE + Vector3(0, 0, 20)) == S_INVALID and controller.last_reason == "Fora do alcance", "Fora de 8 m é bloqueado [BL17]", controller.last_reason)
	_check(_aim(player.global_position - Vector3(0, 0.1, 0)) == S_INVALID and controller.last_reason.contains("Bloqueado"), "Fundação sobre o jogador é bloqueada [BL05]", controller.last_reason)
	var before := _wood_total()
	controller.last_state = S_INVALID
	_check(not controller.confirm() and _wood_total() == before, "Confirmar com prévia inválida não faz nada")


func _test_free_objects() -> void:
	controller.select(CAMPFIRE)
	controller.rotation_steps = 0
	controller.rotate_step(1)
	_check(is_equal_approx(controller.rotation_degrees_y(), 15.0), "R gira em passos de 15° [BL04]")
	var fire_ground := await _place(CAMPFIRE, BASE + Vector3(3.5, 0, 4))
	var yaw := rad_to_deg(fire_ground.global_transform.basis.get_euler().y) if fire_ground != null else 0.0
	_check(fire_ground != null and absf(yaw - 15.0) < 0.5, "Fogueira no chão com 15° de rotação", "yaw=%.1f" % yaw)
	_check(fire_ground != null and fire_ground.support_id == &"" and inventory.count(&"stone") == 8, "Fogueira consome 3 madeira e 2 pedra; apoiada no chão")
	controller.rotation_steps = 0
	var neighbor_pos := BASE + Vector3(0, 0, -3)
	var fire_on_foundation := await _place(CAMPFIRE, neighbor_pos + Vector3(0.5, 0, 0.5))
	var neighbor := manager.find_piece_at(neighbor_pos, &"foundation")
	_check(fire_on_foundation != null and fire_on_foundation.support_id == neighbor.piece_id and absf(fire_on_foundation.global_position.y - 0.3) < 0.01, "Fogueira sobre fundação: apoiada nela, na altura do piso")
	var wall := manager.find_piece_at(BASE + Vector3(0, 0.3, -1.5), &"wall")
	controller.select(CAMPFIRE)
	_check(_aim(BASE + Vector3(0, 0, -1.5)) == S_INVALID and not wall.is_queued_for_deletion(), "Objeto livre em cima de parede é recusado")


func _test_removal() -> void:
	var foundation := manager.find_piece_at(BASE, &"foundation")
	var dependents := manager.get_dependents(foundation)
	var result := manager.remove(foundation, inventory)
	_check(not result["ok"] and manager.get_piece(foundation.piece_id) != null and dependents.size() >= 3, "Remover fundação com peças apoiadas é bloqueado [BL21]", result["message"])

	var neighbor := manager.find_piece_at(BASE + Vector3(0, 0, -3), &"foundation")
	var fire := manager.get_pieces().filter(func(p): return p.support_id == neighbor.piece_id)[0] as BuildingPiece
	var wood_before := inventory.count(&"wood")
	result = manager.remove(fire, inventory)
	_check(result["ok"] and inventory.count(&"wood") == wood_before + 3, "Remover em até 10 s devolve 100% [BL18]")
	await _wait_physics(2)

	var east := manager.find_piece_at(BASE + Vector3(1.5, 0.3, 0), &"wall")
	var north := manager.find_piece_at(BASE + Vector3(0, 0.3, -1.5), &"wall")
	manager.game_time += 11.0
	wood_before = inventory.count(&"wood")
	var fiber_before := inventory.count(&"fiber")
	result = manager.remove(east, inventory)
	_check(result["ok"] and inventory.count(&"wood") == wood_before + 4 and inventory.count(&"fiber") == fiber_before + 1, "Depois de 10 s devolve 75% arredondado para baixo (6→4, 2→1) [BL19]")
	await _wait_physics(2)
	var door := manager.find_piece_at(BASE + Vector3(0, 0.3, 1.5), &"wall")
	manager.remove(door, inventory)
	await _wait_physics(2)
	result = manager.remove(north, inventory)
	_check(not result["ok"] and manager.get_piece(north.piece_id) != null, "Remover a última parede sob um telhado é bloqueado [BL21]", result["message"])

	var roof := manager.find_piece_at(BASE + Vector3(0, 3.3, 0), &"roof")
	var saved := inventory.get_all()
	inventory.capacity = inventory.used_slots()
	inventory.load_counts({&"wood": 50, &"stone": 50})
	inventory.capacity = 2
	result = manager.remove(roof, inventory)
	_check(not result["ok"] and manager.get_piece(roof.piece_id) != null and inventory.count(&"fiber") == 0, "Inventário sem espaço: remoção recusada, nada perdido [BL20]", result["message"])
	inventory.capacity = 20
	inventory.load_counts(saved)

	var total_before := _wood_total()
	manager.remove(roof, inventory)
	await _wait_physics(2)
	manager.remove(north, inventory)
	await _wait_physics(2)
	_check(_wood_total() <= total_before, "Conservação: remover nunca cria madeira [BL09]", "%d -> %d" % [total_before, _wood_total()])
	await _clear_pieces()


func _test_bed_respawn() -> void:
	_give(30, 30)
	var bed := await _place(BED, BASE + Vector3(-2, 0, 3)) as SurvivalBed
	_check(bed != null and inventory.count(&"wood") == 26 and inventory.count(&"fiber") == 24, "Leito construído (4 madeira, 6 fibra)")
	_check(respawn.active_bed == null, "Construir o leito não o ativa [DR19]")
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var result := bed.interact(detector)
	_check(result["ok"] and respawn.active_bed == bed and bed.is_active_respawn, "Interagir define o leito como ponto de retorno [DR19]")
	health.apply_damage(DamageInfo.create(999.0, &"enemy:test"))
	await _wait_physics(1)
	respawn.respawn_now()
	await _wait_physics(1)
	_check(player.global_position.distance_to(bed.global_position) < 2.0, "Respawn ao lado do leito ativo", str(player.global_position))
	player.set_physics_process(false)
	manager.remove(bed, inventory)
	await _wait_physics(2)
	_check(respawn.active_bed == null, "Leito removido deixa de ser ponto de retorno [BL22]")
	health.apply_damage(DamageInfo.create(999.0, &"enemy:test"))
	await _wait_physics(1)
	respawn.respawn_now()
	await _wait_physics(1)
	var spawn := main.get_node("SpawnPoint") as Node3D
	_check(player.global_position.distance_to(spawn.global_position) < 0.5, "Sem leito, respawn no ponto inicial [DR09]")
	player.global_position = BASE + Vector3(0, 0.1, 3.5)
	player.set_physics_process(false)
	await _wait_physics(2)


func _test_mode_rules() -> void:
	controller.exit()
	controller.enter()
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	root.push_input(ev)
	await _wait_physics(1)
	_check(not controller.active and not hud.is_panel_visible(), "Esc sai do modo de construção [BL24]")
	controller.enter()
	health.apply_damage(DamageInfo.create(999.0, &"enemy:test"))
	await _wait_physics(1)
	_check(not controller.active and not controller.enter(), "Morrer sai do modo de construção e impede entrar")
	respawn.respawn_now()
	await _wait_physics(1)
	_check(controller.enter(), "Depois do respawn é possível construir de novo")
	controller.exit()


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
