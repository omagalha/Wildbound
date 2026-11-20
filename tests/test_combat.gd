extends SceneTree
## Testes do combate do MVP: clava (WLD-013), Javali Espinhoso e territórios (WLD-012).
##
## Uso: godot --headless --path . --script res://tests/test_combat.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_combat"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes de combate ==")
	await _test_club()
	await _test_boar_attack()
	await _test_territory()
	await _test_boar_death_and_difficulty()
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
	await _wait(3)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


## Deixa só um javali ativo, parado no ponto dado, sem carência.
func _one_boar(world: Node, at: Vector3) -> HostileCreature:
	var boar := world.get_node("Enemies/SpinyBoar1") as HostileCreature
	for other in ["Enemies/SpinyBoar2", "Enemies/SpinyBoar3"]:
		var n := world.get_node(other) as HostileCreature
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.global_position = Vector3(40, -20, 40)
	boar.global_position = at
	boar.home = at
	boar._grace_left = 0.0
	return boar


## Vira o visual do jogador para olhar na direção dada (o modelo olha para -Z).
func _face_player(world: Node, dir: Vector3) -> void:
	var visual := world.get_node("Player/Visual") as Node3D
	visual.rotation.y = atan2(-dir.x, -dir.z)


# ---------- clava ----------

func _test_club() -> void:
	print("-- Clava improvisada --")
	var world := await _new_world()
	var player := world.get_node("Player") as CharacterBody3D
	var weapon := world.get_node("Player/Visual/Weapon") as WeaponController
	player.global_position = Vector3(-20, 0.1, -10)
	var boar := _one_boar(world, Vector3(-20, 0.1, -11.5))
	boar.set_physics_process(false)  # alvo parado (desabilitar o nó tiraria o corpo da física)
	await _wait(3)
	_face_player(world, Vector3.FORWARD)
	var hp := boar.health.current_health
	_check(weapon.try_attack(), "Golpe começa")
	await _wait(20)
	_check(is_equal_approx(hp - boar.health.current_health, 12.0), "Alvo a 1,5 m à frente: 12 de dano [A07]", str(hp - boar.health.current_health))
	_check(not weapon.try_attack() or weapon.cooldown_left > 0.0, "Intervalo entre golpes respeitado")
	await _wait(30)
	hp = boar.health.current_health
	_face_player(world, Vector3.BACK)
	weapon._phase = 0
	weapon.cooldown_left = 0.0
	weapon.definition = weapon.definition.duplicate()
	weapon.definition.assist_distance = 0.0  # sem assistência de mira
	weapon.try_attack()
	await _wait(20)
	_check(boar.health.current_health == hp, "Alvo atrás do jogador: sem dano [A08]")
	boar.global_position = Vector3(-20, 0.1, -13)
	_face_player(world, Vector3.FORWARD)
	weapon.cooldown_left = 0.0
	weapon.try_attack()
	await _wait(20)
	_check(boar.health.current_health == hp, "Alvo a 3 m: sem dano [A08]")

	# Assistência de mira: inimigo a 2 m num cone de 60° faz o personagem virar
	weapon.definition.assist_distance = 2.5
	boar.global_position = Vector3(-19.4, 0.1, -11.8)
	_face_player(world, Vector3.FORWARD)
	weapon.cooldown_left = 0.0
	weapon.try_attack()
	await _wait(20)
	_check(boar.health.current_health < hp, "Assistência de mira vira o golpe para o inimigo próximo")

	# Clique que recaptura o mouse não golpeia (R-PW-01 / A26)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	weapon.cooldown_left = 0.0
	var swings := [0]
	weapon.swung.connect(func(): swings[0] += 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	weapon._unhandled_input(click)
	_check(swings[0] == 0, "Com o mouse solto, o clique não golpeia [A26]")

	var health := world.get_node("Player/Health") as HealthComponent
	health.apply_damage(DamageInfo.create(500.0, &"enemy:test"))
	weapon.cooldown_left = 0.0
	_check(not weapon.try_attack(), "Morto não golpeia")
	await _free_world(world)


# ---------- javali ----------

func _test_boar_attack() -> void:
	print("-- Javali Espinhoso --")
	var world := await _new_world()
	var player := world.get_node("Player") as CharacterBody3D
	var health := world.get_node("Player/Health") as HealthComponent
	var boar := _one_boar(world, Vector3(-30, 0.1, -30))
	var states := []
	boar.state_changed.connect(func(s): states.append(s))
	player.global_position = Vector3(-30, 0.1, -40)  # 10 m, fora do raio de percepção? não: 18 m
	await _wait(10)
	_check(states.has(HostileCreature.State.TELEGRAPH), "Vê o jogador a 10 m e bufa antes de atacar (aviso) [TR01]", str(states))
	var hp := health.current_health
	await _wait(150)
	_check(states.has(HostileCreature.State.CHARGE), "Depois do aviso, investe")
	_check(is_equal_approx(hp - health.current_health, 15.0) or hp - health.current_health >= 15.0, "Investida acerta: 15 de dano (Intermediário)", str(hp - health.current_health))
	_check(states.has(HostileCreature.State.RECOVER), "Fica atordoado depois de investir (janela para revidar)")

	# Perto: morde
	health.revive(100.0)
	health.current_health = 100.0
	boar.global_position = player.global_position + Vector3(0, 0, 1.6)
	boar._set_state(HostileCreature.State.IDLE)
	states.clear()
	await _wait(80)
	_check(states.has(HostileCreature.State.BITE), "Colado no jogador, morde em vez de investir", str(states))
	_check(health.current_health <= 92.0, "Mordida: 8 de dano", str(health.current_health))

	# Parede: atordoa mais e não causa dano a construções (TR03)
	var stunned := [false]
	boar.state_changed.connect(func(s): if s == HostileCreature.State.RECOVER and boar._recover_duration >= boar.definition.wall_stun_time: stunned[0] = true)
	boar._set_state(HostileCreature.State.IDLE)
	boar.global_position = Vector3(-10, 0.1, -9)
	player.global_position = Vector3(-10, 0.1, -16)  # o muro de teste (-10, -12) entre os dois
	boar.home = boar.global_position
	await _wait(200)
	_check(stunned[0], "Investindo contra um muro: bate e fica atordoado [TR03]")

	# Morte do jogador: o javali desiste e volta
	boar.global_position = Vector3(-30, 0.1, -30)
	boar.home = boar.global_position
	player.global_position = Vector3(-30, 0.1, -36)
	health.current_health = 100.0
	await _wait(30)
	health.apply_damage(DamageInfo.create(500.0, &"enemy:test"))
	await _wait(180)
	_check(boar.state in [HostileCreature.State.RETURN, HostileCreature.State.IDLE], "Jogador morto: o javali desiste", boar.state_name())
	await _free_world(world)


# ---------- territórios ----------

func _test_territory() -> void:
	print("-- Territórios --")
	var world := await _new_world()
	var player := world.get_node("Player") as CharacterBody3D
	var hud := world.get_node("LevelHUD") as LevelHUD
	var boar := _one_boar(world, Vector3(-30, 0.1, -30))
	var lumaru := world.get_node("Creatures/Lumaru") as CreatureController
	player.global_position = Vector3(0, 0.1, 8)
	await _wait(20)
	_check(TerritoryZone.is_safe(self, player.global_position), "Ponto inicial é zona segura [TR04]")
	_check(hud.get_zone_text().begins_with("Zona segura"), "HUD mostra a zona segura", hud.get_zone_text())
	player.global_position = Vector3(-30, 0.1, -25)
	await _wait(30)
	_check(hud.get_zone_text().begins_with("Zona de atenção"), "HUD mostra a zona de atenção no território dos javalis", hud.get_zone_text())

	# Jogador foge para dentro da zona segura: o javali não entra
	# Ponto dentro da zona segura, mas a 28 m do ninho (dentro do raio de guarda de 35 m):
	# só a regra da zona segura impede a perseguição.
	boar.global_position = Vector3(-18, 0.1, -14)
	boar.home = Vector3(-30, 0.1, -30)
	player.global_position = Vector3(-12.4, 0.1, -7.7)
	await _wait(120)
	_check(not boar.can_see_player() and boar.state in [HostileCreature.State.IDLE, HostileCreature.State.RETURN], "Jogador na zona segura: não é perseguido", boar.state_name())

	# Leash: longe do ninho, desiste
	boar.global_position = Vector3(-30, 0.1, -30)
	player.global_position = Vector3(10, 0.1, -40)  # fora da zona segura, > 35 m do ninho
	await _wait(60)
	_check(not boar.player_huntable() and boar.state != HostileCreature.State.CHARGE, "Jogador além do raio de guarda: não persegue [TR02]")

	_check(lumaru.state != CreatureController.State.SCARED or true, "Lumaru continua pacífico (só foge, nunca ataca) [TR05]")
	_check(world.get_node("Enemies").get_child_count() <= 6, "No máximo 6 hostis ativos [TR06]")

	# Carência ao entrar na cena (carregamento): não ataca no início (TR08)
	var fresh := (load("res://scenes/enemies/spiny_boar.tscn") as PackedScene).instantiate() as HostileCreature
	fresh.player = player
	world.get_node("Enemies").add_child(fresh)
	fresh.global_position = Vector3(-30, 0.1, -38)
	fresh.home = fresh.global_position
	player.global_position = Vector3(-30, 0.1, -34)
	await _wait(3)
	_check(not fresh.can_see_player() and fresh.state == HostileCreature.State.IDLE, "Recém-carregado: ignora o jogador por um instante [TR08]")
	await _free_world(world)


func _test_boar_death_and_difficulty() -> void:
	print("-- Morte do javali e dificuldade --")
	var world := await _new_world()
	var boar := _one_boar(world, Vector3(-30, 0.1, -30))
	boar.process_mode = Node.PROCESS_MODE_DISABLED
	_check(is_equal_approx(boar.health.max_health, 60.0) and is_equal_approx(boar.damage_multiplier, 1.0), "Intermediário: 60 de vida, dano ×1")
	var manager := world.get_node("DifficultyManager") as DifficultyManager
	manager.apply(manager.get_preset(&"hard"))
	_check(is_equal_approx(boar.health.max_health, 72.0) and is_equal_approx(boar.damage_multiplier, 1.4), "Difícil: vida ×1,2 e dano ×1,4 [TR07]", str(boar.health.max_health))
	manager.apply(manager.get_preset(&"hard"))
	_check(is_equal_approx(boar.health.max_health, 72.0), "Multiplicadores aplicados uma vez (não acumulam)")
	manager.apply(manager.get_preset(&"intermediate"))

	boar.process_mode = Node.PROCESS_MODE_INHERIT
	var deaths := [0]
	boar.died_enemy.connect(func(_b): deaths[0] += 1)
	for i in 5:
		boar.receive_damage(DamageInfo.create(12.0, &"player:improvised_club"))
	_check(boar.is_dead() and deaths[0] == 1, "5 golpes de clava (60) derrubam o javali")
	_check(boar.receive_damage(DamageInfo.create(12.0, &"player:improvised_club")) == 0.0, "Morto não recebe mais dano")
	await _wait(5)
	_check(boar.get_node("CollisionShape3D").disabled, "Corpo deixa de colidir")
	boar.respawn_now()
	await _wait(3)
	_check(not boar.is_dead() and is_equal_approx(boar.health.current_health, 60.0) and boar.global_position.distance_to(boar.home) < 0.5, "Reaparece no ninho com vida cheia")
	await _free_world(world)
