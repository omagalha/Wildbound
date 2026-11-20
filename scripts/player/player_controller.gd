class_name PlayerController
extends CharacterBody3D
## Movimento do jogador em terceira pessoa.
##
## Responsabilidade única: transformar ações de entrada (InputMap) em
## movimento físico — andar, correr, pular e cair. Não conhece câmera além
## da orientação horizontal (yaw) do nó informado em [member camera_pivot].
##
## Toda leitura de entrada passa por ações nomeadas ("move_forward", "jump"...).
## Controles touch futuros só precisam acionar as mesmas ações
## (ex.: [method Input.action_press]) — nenhuma mudança neste script.

const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_FORWARD := &"move_forward"
const ACTION_BACKWARD := &"move_backward"
const ACTION_JUMP := &"jump"
const ACTION_SPRINT := &"sprint"

@export_group("Movimento")
## Velocidade de caminhada, em m/s.
@export var walk_speed: float = 5.0
## Velocidade com corrida ativa, em m/s.
@export var sprint_speed: float = 8.5
## Aceleração horizontal no chão, em m/s².
@export var acceleration: float = 30.0
## Desaceleração horizontal no chão quando não há entrada, em m/s².
@export var deceleration: float = 40.0
## Fração da aceleração aplicada no ar (0 = sem controle aéreo, 1 = igual ao chão).
@export_range(0.0, 1.0) var air_control: float = 0.35

@export_group("Pulo e gravidade")
## Velocidade vertical inicial do pulo, em m/s.
@export var jump_velocity: float = 5.5
## Multiplicador sobre a gravidade padrão do projeto.
@export var gravity_multiplier: float = 1.0

@export_group("Visual")
## Rapidez com que o modelo gira para a direção do movimento.
@export var turn_speed: float = 12.0

@export_group("Referências")
## Nó cuja rotação Y define o "para frente" do movimento (normalmente o CameraPivot).
@export var camera_pivot: Node3D
## Nó visual que gira para a direção do movimento (o corpo físico não gira).
@export var visual: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	if camera_pivot == null:
		push_warning("PlayerController: camera_pivot não definido; movimento usará a orientação do próprio corpo.")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	var direction := get_move_direction()
	_apply_horizontal_movement(direction, delta)
	move_and_slide()
	_rotate_visual(direction, delta)


## Direção desejada no plano XZ, relativa ao yaw da câmera.
## Comprimento entre 0 e 1 (preserva entrada analógica de futuros controles touch).
func get_move_direction() -> Vector3:
	var input := Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACKWARD)
	if input.is_zero_approx():
		return Vector3.ZERO
	var reference: Node3D = camera_pivot if camera_pivot != null else self
	var yaw := reference.global_rotation.y
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)


func is_sprinting() -> bool:
	return Input.is_action_pressed(ACTION_SPRINT)


func get_target_speed() -> float:
	return sprint_speed if is_sprinting() else walk_speed


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta


func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed(ACTION_JUMP):
		velocity.y = jump_velocity


func _apply_horizontal_movement(direction: Vector3, delta: float) -> void:
	var target := direction * get_target_speed()
	var rate := acceleration if not direction.is_zero_approx() else deceleration
	if not is_on_floor():
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _rotate_visual(direction: Vector3, delta: float) -> void:
	if visual == null or direction.is_zero_approx():
		return
	# O modelo "olha" para -Z; atan2 converte a direção em ângulo Y.
	var target_yaw := atan2(-direction.x, -direction.z)
	# Interpolação exponencial: resultado independente da taxa de quadros.
	var weight := 1.0 - exp(-turn_speed * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
