extends SceneTree
## Testes automatizados da WLD-001, sem frameworks externos.
##
## Uso (na pasta do projeto):
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Código de saída 0 = todos passaram; 1 = alguma falha.
## Estes testes validam estrutura, InputMap e física simulada.
## Não substituem o teste visual/manual (câmera, sensação, mouse real).

const MAIN_SCENE := "res://scenes/main/main.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const WORLD_SCENE := "res://scenes/world/test_world.tscn"

const ACTION_KEYS := {
	&"move_forward": KEY_W,
	&"move_backward": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"jump": KEY_SPACE,
	&"sprint": KEY_SHIFT,
	&"ui_cancel": KEY_ESCAPE,
}

var _passed := 0
var _failed := 0
var _main: Node3D
var _player: PlayerController
var _camera: ThirdPersonCamera


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound WLD-001: testes automatizados ==")
	_test_main_scene_configured()
	_test_input_map()
	_test_scenes_load()
	_test_player_structure()
	_test_world_structure()
	await _setup_simulation()
	await _test_gravity_and_landing()
	await _test_walk_relative_to_camera()
	await _test_sprint_faster_than_walk()
	await _test_jump_only_on_floor()
	await _test_collision_with_obstacle()
	_test_camera_pitch_limits()
	_release_all_actions()
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


func _release_all_actions() -> void:
	for action in ACTION_KEYS.keys():
		Input.action_release(action)


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _reset_player(pos: Vector3) -> void:
	_release_all_actions()
	_player.global_position = pos
	_player.velocity = Vector3.ZERO


# ---------- testes estruturais ----------

func _test_main_scene_configured() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(main_scene == MAIN_SCENE, "Cena principal configurada", main_scene)
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	_check(method == "mobile", "Renderer Mobile configurado", method)


func _test_input_map() -> void:
	for action in ACTION_KEYS.keys():
		if not InputMap.has_action(action):
			_check(false, "InputMap: ação '%s' existe" % action)
			continue
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var key := ev as InputEventKey
				if key.physical_keycode == ACTION_KEYS[action] or key.keycode == ACTION_KEYS[action]:
					found = true
		_check(found, "InputMap: '%s' -> %s" % [action, OS.get_keycode_string(ACTION_KEYS[action])])


func _test_scenes_load() -> void:
	for path in [MAIN_SCENE, PLAYER_SCENE, WORLD_SCENE]:
		var scene := load(path) as PackedScene
		_check(scene != null and scene.can_instantiate(), "Cena carrega: " + path)


func _test_player_structure() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	_check(player is CharacterBody3D, "Player é CharacterBody3D")
	_check(player is PlayerController, "Player usa PlayerController")
	var shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_check(shape != null and shape.shape != null, "Player tem CollisionShape3D com forma")
	_check(player.get_node_or_null("Visual/MeshInstance3D") is MeshInstance3D, "Player tem Visual/MeshInstance3D")
	_check(player.get_node_or_null("CameraPivot") is ThirdPersonCamera, "CameraPivot usa ThirdPersonCamera")
	_check(player.get_node_or_null("CameraPivot/SpringArm3D") is SpringArm3D, "SpringArm3D presente")
	_check(player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") is Camera3D, "Camera3D presente")
	var pc := player as PlayerController
	_check(pc.camera_pivot != null and pc.visual != null, "Referências exportadas do Player resolvidas")
	var arm := player.get_node("CameraPivot/SpringArm3D") as SpringArm3D
	_check(arm.collision_mask & 1 == 1 and (pc.collision_layer & 1) == 0,
		"SpringArm colide com o mundo e ignora o Player")
	player.free()


func _test_world_structure() -> void:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate()
	var ground := world.get_node_or_null("Ground") as StaticBody3D
	_check(ground != null, "Mundo tem Ground (StaticBody3D)")
	var gshape := world.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
	var box := gshape.shape as BoxShape3D if gshape != null else null
	_check(box != null and box.size.x >= 100.0 and box.size.z >= 100.0, "Ground com colisão de ~100x100 m")
	_check(world.get_node_or_null("WorldEnvironment") is WorldEnvironment, "WorldEnvironment presente")
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	_check(sun != null and sun.shadow_enabled, "DirectionalLight3D com sombras")
	world.free()


# ---------- testes de simulação física ----------

func _setup_simulation() -> void:
	_main = _instantiate_main_isolated() as Node3D
	root.add_child(_main)
	_player = _main.get_node("Player") as PlayerController
	_camera = _player.get_node("CameraPivot") as ThirdPersonCamera
	await _wait_physics(2)


func _test_gravity_and_landing() -> void:
	_reset_player(Vector3(0, 3, 20))
	await _wait_physics(3)
	_check(_player.velocity.y < 0.0, "Gravidade: jogador acelera para baixo no ar")
	await _wait_physics(90)
	_check(_player.is_on_floor(), "Colisão: jogador pousa no chão")
	_check(absf(_player.global_position.y) < 0.1, "Colisão: jogador não atravessa o chão",
		"y=%.3f" % _player.global_position.y)


func _test_walk_relative_to_camera() -> void:
	# Câmera olhando para -Z (yaw 0): "frente" deve mover para -Z.
	_reset_player(Vector3(0, 0.05, 20))
	_camera.add_look_input(Vector2(_camera.get_yaw(), 0))  # zera o yaw
	await _wait_physics(5)
	var start := _player.global_position
	Input.action_press(&"move_forward")
	await _wait_physics(30)
	Input.action_release(&"move_forward")
	var moved := _player.global_position - start
	_check(moved.z < -1.0 and absf(moved.x) < 0.2, "Movimento: W com yaw 0 vai para -Z", str(moved))

	# Gira a câmera 90° para a direita: "frente" deve virar +X.
	_camera.add_look_input(Vector2(PI / 2.0, 0))
	await _wait_physics(20)
	start = _player.global_position
	Input.action_press(&"move_forward")
	await _wait_physics(30)
	Input.action_release(&"move_forward")
	moved = _player.global_position - start
	_check(moved.x > 1.0 and absf(moved.z) < 0.5, "Movimento: W acompanha a rotação da câmera (+X)", str(moved))

	var vis_yaw := wrapf(_player.visual.rotation.y, -PI, PI)
	_check(absf(angle_difference(vis_yaw, -PI / 2.0)) < 0.2,
		"Visual gira para a direção do movimento", "yaw=%.2f" % vis_yaw)
	_camera.add_look_input(Vector2(-PI / 2.0, 0))


func _test_sprint_faster_than_walk() -> void:
	_reset_player(Vector3(0, 0.05, 20))
	await _wait_physics(5)
	Input.action_press(&"move_left")
	await _wait_physics(30)
	var walk := _horizontal_speed()
	Input.action_press(&"sprint")
	await _wait_physics(30)
	var run := _horizontal_speed()
	_release_all_actions()
	_check(is_equal_approx(snappedf(walk, 0.01), snappedf(_player.walk_speed, 0.01)), "Caminhada atinge walk_speed", "%.2f" % walk)
	_check(run > walk + 1.0, "Corrida mais rápida que caminhada", "walk=%.2f run=%.2f" % [walk, run])
	await _wait_physics(30)
	_check(_horizontal_speed() < 0.05, "Desacelera até parar sem entrada")


func _test_jump_only_on_floor() -> void:
	_reset_player(Vector3(0, 0.05, 20))
	await _wait_physics(10)
	Input.action_press(&"jump")
	await _wait_physics(2)
	Input.action_release(&"jump")
	_check(_player.velocity.y > 0.0 and not _player.is_on_floor(), "Pulo a partir do chão",
		"vy=%.2f" % _player.velocity.y)
	await _wait_physics(10)
	# Tentativa de pulo duplo no ar: não deve aumentar a velocidade vertical.
	var vy_before := _player.velocity.y
	Input.action_press(&"jump")
	await _wait_physics(2)
	Input.action_release(&"jump")
	_check(_player.velocity.y < vy_before, "Sem pulo no ar", "antes=%.2f depois=%.2f" % [vy_before, _player.velocity.y])
	await _wait_physics(90)
	_check(_player.is_on_floor(), "Pousa após o pulo")


func _test_collision_with_obstacle() -> void:
	# TallBlock (3 m) está em (5, 0, -5). Andar de +X contra ele deve parar antes.
	_reset_player(Vector3(9, 0.05, -5))
	_camera.add_look_input(Vector2(_camera.get_yaw(), 0))
	await _wait_physics(5)
	Input.action_press(&"move_left")
	await _wait_physics(120)
	_release_all_actions()
	_check(_player.global_position.x > 5.5, "Colisão: obstáculo alto bloqueia o jogador",
		"x=%.2f" % _player.global_position.x)


func _test_camera_pitch_limits() -> void:
	_camera.add_look_input(Vector2(0, 100.0))
	_check(is_equal_approx(_camera.get_pitch(), deg_to_rad(_camera.min_pitch_degrees)), "Câmera: limite inferior de inclinação")
	_camera.add_look_input(Vector2(0, -100.0))
	_check(is_equal_approx(_camera.get_pitch(), deg_to_rad(_camera.max_pitch_degrees)), "Câmera: limite superior de inclinação")


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
