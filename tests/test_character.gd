extends SceneTree
## Testes do personagem animado (modelo + bibliotecas de animação Quaternius).
##
## Uso: godot --headless --path . --script res://tests/test_character.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_DIR := "user://test_saves_character"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound: testes do personagem ==")
	await _test_model()
	await _test_locomotion()
	await _test_actions()
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
	return world


func _free_world(world: Node) -> void:
	world.queue_free()
	await _wait(2)


func _animator(world: Node) -> CharacterAnimator:
	return world.get_node("Player/CharacterAnimator") as CharacterAnimator


# ---------- modelo ----------

func _test_model() -> void:
	print("-- Modelo --")
	var world := await _new_world()
	var animator := _animator(world)
	var player := world.get_node("Player") as PlayerController
	_check(animator.model != null and animator.model.get_parent() == player.visual, "Modelo carregado dentro do Visual")
	_check(not (player.visual.get_node("MeshInstance3D") as Node3D).visible, "Cápsula provisória escondida")
	_check(animator.skeleton != null and animator.skeleton.find_bone("hand_r") >= 0, "Esqueleto com mãos")
	var missing := []
	for clip in ["idle", "idle_torch", "jog", "sprint", "air", "attack", "attack_heavy", "hit", "death", "eat", "harvest", "chop", "pickup", "interact"]:
		if not animator.has_clip(clip):
			missing.append(clip)
	_check(missing.is_empty(), "Todas as animações do jogo encontradas", str(missing))
	var weapon := world.get_node("Player/Visual/Weapon") as WeaponController
	_check(not weapon.procedural_swing, "A animação faz o golpe (sem giro no código)")
	await _wait(5)
	var hand := animator.skeleton.global_transform * animator.skeleton.get_bone_global_pose(animator.skeleton.find_bone("hand_r"))
	var club := weapon.get_node("Club") as Node3D
	_check(club.global_position.distance_to(hand.origin) < 0.2, "Clava presa na mão direita", "%.2f m" % club.global_position.distance_to(hand.origin))
	_check(weapon.get_node_or_null("Club/Head") != null, "Arma continua no mesmo lugar da árvore")
	var head := weapon.get_node("Club/Head") as Node3D
	var up := (head.global_position - club.global_position)
	_check(up.length() > 0.4 and up.length() < 0.8, "Cabeça da clava fica na ponta do cabo, longe do punho", "%.2f" % up.length())

	world.get_node("Player/Inventory").add_item(&"torch", 1)
	(world.get_node("PlayerEquipment") as PlayerEquipment).set_torch(true)
	await _wait(5)
	var lhand := animator.skeleton.global_transform * animator.skeleton.get_bone_global_pose(animator.skeleton.find_bone("hand_l"))
	var torch := player.visual.get_node("Torch") as Node3D
	_check(torch.global_position.distance_to(lhand.origin) < 0.2, "Tocha presa na mão esquerda")
	_check((torch.global_transform.basis.y).y > 0.3 or animator.current_clip() == "idle_torch", "Tocha em pé")
	await _free_world(world)


# ---------- locomoção ----------

func _test_locomotion() -> void:
	print("-- Locomoção --")
	var world := await _new_world()
	var animator := _animator(world)
	var player := world.get_node("Player") as PlayerController
	await _wait(30)
	_check(animator.current_clip() == "idle", "Parado: idle", animator.current_clip())
	player.set_physics_process(false)
	player.velocity = Vector3(0, 0, -5)
	await _wait(3)
	_check(animator.current_clip() == "jog", "Andando: trote", animator.current_clip())
	var walk_rate := animator.anim.speed_scale
	player.velocity = Vector3(0, 0, -2.5)
	await _wait(2)
	_check(animator.anim.speed_scale < walk_rate, "Mais devagar, passos mais lentos")
	Input.action_press(&"sprint")
	player.velocity = Vector3(0, 0, -8.5)
	await _wait(3)
	_check(animator.current_clip() == "sprint", "Correndo: sprint", animator.current_clip())
	Input.action_release(&"sprint")
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	player.global_position += Vector3(0, 4, 0)
	await _wait(4)
	_check(animator.current_clip() == "air", "No ar: pulo", animator.current_clip())
	await _wait(90)
	_check(animator.current_clip() == "idle", "Pousou: idle de novo", animator.current_clip())
	await _free_world(world)


# ---------- ações ----------

func _test_actions() -> void:
	print("-- Ações --")
	var world := await _new_world()
	var animator := _animator(world)
	var player := world.get_node("Player") as PlayerController
	await _wait(20)  # deixa pousar antes de congelar a física
	player.set_physics_process(false)
	var weapon := world.get_node("Player/Visual/Weapon") as WeaponController
	weapon.require_captured_mouse = false
	await _wait(5)
	weapon.try_attack()
	await _wait(1)
	_check(animator.current_clip() == "attack", "Clique: golpe", animator.current_clip())
	await _wait(60)
	_check(animator.current_clip() == "idle", "Golpe termina e volta ao idle", animator.current_clip())

	world.get_node("Player/Inventory").add_item(&"stone_spear", 1)
	var equipment := world.get_node("PlayerEquipment") as PlayerEquipment
	equipment.select_slot(equipment.slot_of(&"stone_spear"))
	await _wait(1)
	weapon.try_attack()
	await _wait(1)
	_check(animator.current_clip() == "attack_heavy", "Com lança: golpe pesado", animator.current_clip())
	await _wait(80)

	var health := player.get_node("Health") as HealthComponent
	health.apply_damage(DamageInfo.create(10.0, &"enemy:test"))
	await _wait(1)
	_check(animator.current_clip() == "hit", "Levou dano: recua", animator.current_clip())
	await _wait(80)

	var hunger := player.get_node("Hunger") as HungerComponent
	hunger.set_hunger(40.0)
	world.get_node("Player/Inventory").add_item(&"wild_berries", 1)
	(player.get_node("FoodConsumer") as FoodConsumer).try_eat()
	await _wait(1)
	_check(animator.current_clip() == "eat", "Comer: animação de comer", animator.current_clip())
	player.velocity = Vector3(0, 0, -5)
	await _wait(3)
	_check(animator.current_clip() == "jog", "Sair andando interrompe ações curtas", animator.current_clip())
	player.velocity = Vector3.ZERO
	await _wait(3)

	var detector := player.get_node("InteractionDetector") as InteractionDetector
	var forest := world.get_node("TestWorld/Forest") as ForestGenerator
	world.get_node("Player/Inventory").add_item(&"stone_axe", 1)
	detector.interacted.emit(forest.tree_bodies[0], {"ok": true})
	await _wait(1)
	_check(animator.current_clip() == "chop", "Cortar árvore: machadada", animator.current_clip())
	await _wait(80)
	var bush := world.get_node("ResourceField/BerryBushs/BerryBush01")
	detector.interacted.emit(bush, {"ok": true})
	await _wait(1)
	_check(animator.current_clip() == "harvest", "Colher frutas: colheita", animator.current_clip())
	await _wait(120)

	health.apply_damage(DamageInfo.create(500.0, &"enemy:test"))
	await _wait(1)
	_check(animator.current_clip() == "death", "Morreu: cai", animator.current_clip())
	await _wait(90)
	_check(animator.current_clip() == "death", "Continua caído até reaparecer")
	if health.is_dead():
		health.revive(80.0)
	await _wait(3)
	_check(animator.current_clip() == "idle", "Reapareceu: de pé", animator.current_clip())
	await _free_world(world)


# ---------- animais ----------

func _test_creatures() -> void:
	print("-- Animais --")
	var world := await _new_world()
	var lumaru := world.get_node("Creatures/Lumaru") as CreatureController
	var lmodel := lumaru.get_node("CreatureModel") as CreatureModel
	_check(lmodel.model != null and lmodel.anim != null, "Lumaru com modelo animado (raposa)")
	var hidden := true
	for child in lumaru.visual.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			hidden = false
	_check(hidden, "Formas provisórias do Lumaru escondidas")
	var missing := []
	for st in ["idle", "walk", "run", "alert", "eat", "happy"]:
		if not lmodel.has_clip(st):
			missing.append(st)
	_check(missing.is_empty(), "Lumaru tem todas as animações", str(missing))
	await _wait(5)
	_check(lmodel.current == lumaru.get_anim_state() or lmodel.current == "hit", "Animação segue o estado do Lumaru", "%s vs %s" % [lmodel.current, lumaru.get_anim_state()])

	var hunt := world.get_node("NightHunt") as NightHunt
	hunt.set_physics_process(false)
	hunt.spawn_pack()
	var wolf := hunt.wolves()[0]
	await _wait(3)
	var wmodel := wolf.get_node("CreatureModel") as CreatureModel
	_check(wmodel.model != null and wmodel.has_clip("attack") and wmodel.has_clip("death"), "Lobo com modelo e animações de ataque e morte")
	_check(wmodel.model.scale.x > 0.0 and wmodel.model.scale.x < 1.0, "Lobo escalado para ~1,5 m")
	wolf._set_state(HostileCreature.State.BITE)
	await _wait(2)
	_check(wmodel.current == "attack", "Mordida: animação de ataque", wmodel.current)
	wolf.receive_damage(DamageInfo.create(5.0, &"player:test"))
	await _wait(1)
	_check(wmodel.current == "hit" and wmodel._meshes[0].material_overlay != null, "Golpe: reage e pisca")
	await _wait(12)
	_check(wmodel._meshes[0].material_overlay == null, "Piscada termina")
	wolf.receive_damage(DamageInfo.create(500.0, &"player:test"))
	await _wait(3)
	_check(wmodel.current == "death" and is_zero_approx(wolf.visual.rotation.z), "Morte: animação, sem tombar duas vezes")
	await _free_world(world)
