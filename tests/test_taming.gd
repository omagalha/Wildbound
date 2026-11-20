extends SceneTree
## Testes do Wild Bond MVP (Lumaru) e do Instinto Selvagem.
##
## Uso: godot --headless --path . --script res://tests/test_taming.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_taming"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de domesticação ==")
	_wipe_dir()
	_test_rules()
	await _test_in_world()
	await _test_companion()
	await _test_instinct()
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


func _new_taming() -> TamingComponent:
	var t := TamingComponent.new()
	t.profile = load("res://resources/creatures/lumaru_taming.tres") as TamingProfile
	return t


func _inventory_with(berries: int) -> Inventory:
	var inv := Inventory.new()
	inv.catalog = load("res://resources/items/item_catalog.tres") as ItemCatalog
	if berries > 0:
		inv.add_item(&"wild_berries", berries)
	return inv


## Põe o jogador parado ao lado da criatura e a deixa calma.
func _stand_next_to(world: Node, lumaru: CreatureController) -> void:
	var player := world.get_node("Player") as CharacterBody3D
	player.velocity = Vector3.ZERO
	player.global_position = lumaru.global_position + Vector3(1.4, 0, 0)
	await _wait(2)


# ---------- regras (sem cena) ----------

func _test_rules() -> void:
	print("-- Regras de confiança e medo --")
	var t := _new_taming()
	var inv := _inventory_with(6)
	var r := t.try_feed(inv, 1.0)
	_check(r["ok"] and is_equal_approx(t.trust, 25.0) and inv.count(&"wild_berries") == 5, "Fruta aceita: +25 confiança, 1 fruta consumida [T01]")

	var empty := _inventory_with(0)
	var t2 := _new_taming()
	r = t2.try_feed(empty, 1.0)
	_check(not r["ok"] and r.get("reason") == TamingComponent.REASON_NO_ITEM and t2.trust == 0.0, "Sem fruta: 'no_item', nada muda [T02]")

	r = t2.try_feed(inv, 3.0)
	_check(r.get("reason") == TamingComponent.REASON_TOO_FAR and inv.count(&"wild_berries") == 5, "Longe demais: 'too_far', nada consumido [T03]")

	r = t.try_feed(inv, 1.0)
	_check(r.get("reason") == TamingComponent.REASON_COOLDOWN and inv.count(&"wild_berries") == 5 and is_equal_approx(t.trust, 25.0), "Durante o intervalo de 8 s: 'cooldown', nada consumido [T04]")
	var left := t.cooldown_left
	t.tick(1.0, false)
	t.try_feed(inv, 1.0)
	_check(is_equal_approx(t.cooldown_left, left - 1.0), "Recusa não reinicia o intervalo [T17]")

	var t3 := _new_taming()
	t3.tick(0.016, true)
	_check(is_equal_approx(t3.fear, 35.0), "Correr perto: medo +35 [T05]")
	t3.tick(0.5, true)
	_check(is_equal_approx(t3.fear, 35.0), "Medo sobe no máximo uma vez por segundo")
	_check(t3.try_feed(inv, 1.0).get("reason") == TamingComponent.REASON_SCARED, "Medo entre 31 e 70: recusa 'scared' sem consumir [T13]")
	var scared_count := [0]
	t3.scared.connect(func(): scared_count[0] += 1)
	t3.trust = 20.0
	t3.tick(0.6, true)
	t3.tick(1.0, true)
	_check(t3.is_fleeing() and scared_count[0] == 1 and is_equal_approx(t3.trust, 10.0), "Medo > 70: foge e perde 10 de confiança uma vez [T06/T15]", "fear=%s trust=%s n=%d" % [t3.fear, t3.trust, scared_count[0]])
	for i in 20:
		t3.tick(1.0, false)
	_check(not t3.is_fleeing() and t3.fear <= 30.0, "Sem ameaça, o medo cai 5/s e a fuga termina")

	var t4 := _new_taming()
	t4.tick(10.0, false)
	_check(t4.fear == 0.0, "Andar devagar não gera medo [T14]")
	t4.trust = 5.0
	t4.tick(0.1, true); t4.tick(1.0, true); t4.tick(1.0, true)
	_check(t4.trust == 0.0, "Confiança nunca fica abaixo de 0 [T16]")

	var t5 := _new_taming()
	var bonds := [0]
	t5.bond_completed.connect(func(): bonds[0] += 1)
	var inv5 := _inventory_with(10)
	for i in 4:
		t5.try_feed(inv5, 1.0)
		t5.tick(8.1, false)
	_check(t5.bonded and bonds[0] == 1 and inv5.count(&"wild_berries") == 6, "4 frutas respeitando o intervalo concluem o vínculo [T12]")
	r = t5.try_feed(inv5, 1.0)
	_check(r.get("reason") == TamingComponent.REASON_BONDED and bonds[0] == 1 and t5.trust == 100.0, "Vínculo emitido uma única vez; confiança não passa de 100 [T07/T16]")
	_check(t5.try_feed(_inventory_with(1), 1.0, false).get("reason") == TamingComponent.REASON_BONDED, "Domesticado ignora o resto das validações")
	_check(_new_taming().try_feed(inv5, 1.0, false).get("reason") == TamingComponent.REASON_REQUIREMENTS, "Sem o conhecimento exigido: 'requirements_not_met'")

	var p := load("res://resources/creatures/lumaru_taming.tres") as TamingProfile
	p = p.duplicate()
	p.preferred_gain = 50.0
	var t6 := TamingComponent.new()
	t6.profile = p
	t6.try_feed(_inventory_with(1), 1.0)
	_check(is_equal_approx(t6.trust, 50.0), "Mudar o .tres muda o comportamento sem mexer no código [T20]")
	for node in [t, t2, t3, t4, t5, t6, inv, empty, inv5]:
		node.free()


# ---------- no mundo ----------

func _test_in_world() -> void:
	print("-- Lumaru no mundo --")
	var world := await _new_world()
	var lumaru := world.get_node("Creatures/Lumaru") as CreatureController
	var player := world.get_node("Player") as CharacterBody3D
	var detector := world.get_node("Player/InteractionDetector") as InteractionDetector
	var inventory := world.get_node("Player/Inventory") as Inventory
	var hud := world.get_node("TamingHUD") as TamingHUD
	var start := lumaru.global_position
	_check(lumaru.state == CreatureController.State.IDLE and lumaru.distance_to_player() > 20.0, "Lumaru começa selvagem na clareira, longe do início")
	await _wait(120)
	_check(lumaru.global_position.distance_to(lumaru.home) <= lumaru.definition.home_radius + 1.0, "Vagando, fica dentro da área de origem")
	_check(start.distance_to(lumaru.global_position) > 0.05 or lumaru._pause_left > 0.0, "Vaga pela clareira (anda ou pausa)")

	await _stand_next_to(world, lumaru)
	await _wait(3)
	_check(lumaru.state == CreatureController.State.ALERT, "Jogador perto: fica atento e para", lumaru.state_name())
	_check(hud.get_title().begins_with("LUMARU SELVAGEM"), "HUD de domesticação aparece perto dele", hud.get_title())
	_check(hud.get_hint().contains("frutas"), "Sem frutas, a dica manda colher", hud.get_hint())

	inventory.add_item(&"wild_berries", 6)
	detector.refresh_focus()
	_check(detector.get_focused() == lumaru, "Lumaru vira o alvo do [E]")
	var result := detector.try_interact()
	_check(result["ok"] and is_equal_approx(lumaru.taming.trust, 25.0) and inventory.count(&"wild_berries") == 5, "[E] perto dele oferece uma fruta (+25%)", str(result))
	await _wait(2)
	_check(lumaru.state == CreatureController.State.EATING, "Depois de comer, entra no estado 'Comendo'")

	# Assustar correndo
	var t := lumaru.taming
	t.cooldown_left = 0.0
	player.velocity = Vector3(8.5, 0, 0)
	await _wait(150)
	_check(lumaru.state == CreatureController.State.SCARED or t.is_fleeing(), "Correr perto o assusta [T06]", lumaru.state_name())
	_check(is_equal_approx(t.trust, 15.0), "Fugir custa 10 de confiança", str(t.trust))
	var flee_start := lumaru.global_position.distance_to(player.global_position)
	await _wait(60)
	_check(lumaru.global_position.distance_to(player.global_position) > flee_start, "Ao fugir, se afasta do jogador")
	player.velocity = Vector3.ZERO
	await _wait(960)  # medo cai 5/s: de ~100 a 30 leva ~14 s
	_check(lumaru.is_wild() and not t.is_fleeing() and lumaru.state != CreatureController.State.SCARED, "Sem perseguição, se acalma e volta ao normal", lumaru.state_name())

	# Completar o vínculo
	var experience := world.get_node("Progression/Experience") as ExperienceComponent
	var xp_before := experience.total_xp
	for i in 4:
		await _stand_next_to(world, lumaru)
		t.cooldown_left = 0.0
		lumaru.interact(detector)
		await _wait(100)
	_check(t.bonded, "Com confiança 100, o vínculo se completa", str(t.trust))
	await _wait(100)
	_check(lumaru.is_following(), "Depois da reação de vínculo, passa a seguir [8]", lumaru.state_name())
	_check(experience.total_xp - xp_before == 100 and experience.has_first(&"tame", &"lumaru"), "Domesticar o Lumaru dá 100 XP uma vez", str(experience.total_xp - xp_before))
	var berries := inventory.count(&"wild_berries")
	await _stand_next_to(world, lumaru)
	lumaru.interact(detector)
	_check(inventory.count(&"wild_berries") == berries and lumaru.state == CreatureController.State.STAYING, "[E] no companheiro dá ordem, sem gastar fruta [T18]")
	lumaru.interact(detector)
	_check(lumaru.is_following(), "[E] de novo volta a seguir")
	await _free_world(world)


func _bonded_world() -> Array:
	var world := await _new_world()
	var lumaru := world.get_node("Creatures/Lumaru") as CreatureController
	lumaru.apply_save_data({"following": true, "position": [0.0, 0.1, 5.0]})
	await _wait(3)
	return [world, lumaru]


func _test_companion() -> void:
	print("-- Companheiro --")
	var pair := await _bonded_world()
	var world: Node = pair[0]
	var lumaru: CreatureController = pair[1]
	var player := world.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(0, 0.1, 8)
	# Jogador anda 12 m (simulado): o companheiro acompanha a ~3 m
	for i in 120:
		player.global_position += Vector3(0.1, 0, 0)
		await physics_frame
	await _wait(120)
	var d := lumaru.distance_to_player()
	_check(d < 4.0 and d > 1.5, "Seguir: acompanha a ~3 m enquanto o jogador anda [T08]", "%.2f m" % d)

	lumaru.set_following(false)
	var spot := lumaru.global_position
	player.global_position += Vector3(0, 0, -15)
	await _wait(120)
	_check(lumaru.global_position.distance_to(spot) < 0.3, "Ficar: permanece no ponto [T09]")
	player.global_position = spot + Vector3(30, 0, 0)
	await _wait(200)
	_check(lumaru.global_position.distance_to(spot) < 0.3, "Parado não é reposicionado, mesmo longe")

	lumaru.set_following(true)
	player.global_position = Vector3(-30, 0.1, 30)
	await _wait(200)
	d = lumaru.distance_to_player()
	_check(d >= 2.0 and d <= 6.0, "Mais de 20 m por 2 s: reaparece 3–5 m atrás do jogador [T19]", "%.2f m" % d)
	_check(lumaru.is_on_floor() or lumaru.global_position.y < 0.5, "Reaparece em chão válido")

	# Preso atrás de um muro (o Wall de teste em -10, -12)
	player.global_position = Vector3(-10, 0.1, -16)
	lumaru.global_position = Vector3(-10, 0.1, -8.5)
	await _wait(260)
	d = lumaru.distance_to_player()
	_check(d < 6.0, "Preso atrás do muro: reposicionado sem travar [T10]", "%.2f m" % d)

	# Respawn do jogador
	var respawn := world.get_node("SimpleRespawn") as SimpleRespawn
	player.global_position = Vector3(25, 0.1, 25)
	lumaru.global_position = Vector3(25, 0.1, 22)
	await _wait(3)
	var health := world.get_node("Player/Health") as HealthComponent
	health.apply_damage(DamageInfo.create(500.0, &"enemy:test"))
	await _wait(2)
	respawn.respawn_now()
	await _wait(3)
	_check(lumaru.is_companion() and lumaru.distance_to_player() < 6.0, "Jogador morre e renasce: companheiro reaparece perto, ainda domesticado")
	await _free_world(world)


func _test_instinct() -> void:
	print("-- Instinto Selvagem --")
	var pair := await _bonded_world()
	var world: Node = pair[0]
	var lumaru: CreatureController = pair[1]
	var instinct := lumaru.get_node("WildInstinct") as WildInstinct
	var player := world.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(-1, 0.1, 13)
	lumaru.global_position = Vector3(-1, 0.1, 11)
	instinct.cooldown_left = 0.0
	var hits := []
	instinct.signaled.connect(func(target): hits.append(target))
	await _wait(80)
	_check(hits.size() == 1, "Seguindo e com recurso perto: sinaliza sozinho [4.1]", str(hits.size()))
	var target: Node3D = hits[0] if not hits.is_empty() else null
	_check(target != null and target.get_resource_category() in [&"wood", &"stone", &"fruit"], "Alvo é madeira, pedra ou fruta (nunca fibra)")
	_check(target != null and lumaru.global_position.distance_to(target.global_position) <= 12.0, "Alvo dentro de 12 m")
	_check(instinct.marker.visible and is_equal_approx(instinct.cooldown_left, 20.0) or instinct.cooldown_left > 18.0, "Indicador visível e recarga de 20 s começou")
	var inventory := world.get_node("Player/Inventory") as Inventory
	_check(inventory.get_all().is_empty(), "Instinto não coleta nada nem mexe no inventário")
	await _wait(200)
	_check(not instinct.marker.visible, "Indicador some depois de 3 s")
	_check(hits.size() == 1, "Durante a recarga não sinaliza de novo")
	instinct.cooldown_left = 0.0
	await _wait(40)
	_check(hits.size() == 2 and hits[1] != hits[0], "Não repete o mesmo recurso por 60 s")

	lumaru.set_following(false)
	instinct.cooldown_left = 0.0
	await _wait(80)
	_check(hits.size() == 2, "Parado (Ficar): instinto não dispara")

	# Sem alvo, sem recarga
	lumaru.set_following(true)
	var empty := _spot_without_resources(world, 16.0)
	player.global_position = empty
	lumaru.global_position = empty + Vector3(0, 0, 2)
	instinct.cooldown_left = 0.0
	await _wait(80)
	_check(hits.size() == 2 and instinct.cooldown_left == 0.0, "Sem recurso no alcance: nada sinalizado e recarga não começa")
	await _free_world(world)


func _test_save() -> void:
	print("-- Save do companheiro --")
	var pair := await _bonded_world()
	var world: Node = pair[0]
	var lumaru: CreatureController = pair[1]
	lumaru.set_following(false)
	lumaru.global_position = Vector3(6, 0.1, -3)
	await _wait(3)
	var spot := lumaru.global_position
	var save := world.get_node("SaveManager") as SaveManager
	_check(save.save_game(), "Salvar com o Lumaru domesticado")
	await _free_world(world)

	world = await _new_world()
	save = world.get_node("SaveManager") as SaveManager
	lumaru = world.get_node("Creatures/Lumaru") as CreatureController
	_check(await save.load_game() == SaveManager.STATUS_LOADED, "Carregar")
	await _wait(3)
	_check(lumaru.is_companion() and lumaru.state == CreatureController.State.STAYING and lumaru.taming.bonded, "Continua domesticado e parado [T11]", lumaru.state_name())
	_check(lumaru.global_position.distance_to(spot) < 0.5, "Posição preservada")
	_check(world.get_node("Creatures").get_child_count() == 1, "Sem duplicar o Lumaru")
	await _free_world(world)

	# Selvagem não grava confiança
	world = await _new_world()
	lumaru = world.get_node("Creatures/Lumaru") as CreatureController
	lumaru.taming.trust = 50.0
	_check(lumaru.get_save_data().is_empty(), "Selvagem não grava progresso de confiança (MVP)")
	await _free_world(world)


## Um ponto do mapa sem nenhuma fonte de recurso a menos de [param clearance] m.
func _spot_without_resources(world: Node, clearance: float) -> Vector3:
	var nodes := world.find_children("*", "ResourceNode", true, false)
	for x in range(-40, 41, 8):
		for z in range(-40, 41, 8):
			var p := Vector3(x, 0.1, z)
			if Vector2(x, z).length() < 30.0:
				continue
			var free := true
			for n in nodes:
				var d := (n as Node3D).global_position - p
				d.y = 0.0
				if d.length() < clearance:
					free = false
					break
			if free:
				return p
	return Vector3(-40, 0.1, -40)
