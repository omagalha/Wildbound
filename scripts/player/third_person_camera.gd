class_name ThirdPersonCamera
extends Node3D
## Câmera orbital em terceira pessoa.
##
## Este script fica no CameraPivot: o pivô gira em Y (yaw) e o SpringArm3D
## filho gira em X (pitch). O SpringArm3D encurta o braço ao colidir com o
## cenário, impedindo que a câmera atravesse chão e obstáculos.
##
## A rotação vem de eventos de mouse (deslocamento em pixels), então não
## depende da taxa de quadros. Controles touch futuros podem chamar
## [method add_look_input] com o deslocamento de um arraste.
##
## Também gerencia a captura do mouse: captura ao iniciar, libera com
## "ui_cancel" (ESC) e recaptura com clique na janela.

const ACTION_RELEASE_MOUSE := &"ui_cancel"

@export_group("Sensibilidade")
## Radianos de rotação por pixel de movimento do mouse.
@export var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false

@export_group("Limites")
## Inclinação mínima (negativo = câmera acima, olhando para baixo), em graus.
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -70.0
## Inclinação máxima (positivo = câmera abaixo, olhando para cima), em graus.
@export_range(0.0, 89.0) var max_pitch_degrees: float = 25.0
## Inclinação ao iniciar, em graus.
@export_range(-89.0, 89.0) var initial_pitch_degrees: float = -15.0

@export_group("Comportamento")
@export var capture_mouse_on_start: bool = true

@export_group("Referências")
@export var spring_arm: SpringArm3D

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_yaw = rotation.y
	_pitch = clampf(deg_to_rad(initial_pitch_degrees), deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_apply_rotation()
	if capture_mouse_on_start:
		set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_RELEASE_MOUSE):
		set_mouse_captured(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and not is_mouse_captured():
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_mouse_captured():
		var motion := event as InputEventMouseMotion
		# screen_relative ignora o fator de stretch do viewport,
		# mantendo a sensibilidade igual em qualquer resolução.
		add_look_input(motion.screen_relative * mouse_sensitivity)


## Aplica rotação em radianos: x = horizontal (yaw), y = vertical (pitch).
## Valores positivos de x giram para a direita; positivos de y olham para baixo.
func add_look_input(look_radians: Vector2) -> void:
	_yaw -= look_radians.x
	var vertical := -look_radians.y if invert_y else look_radians.y
	_pitch = clampf(_pitch - vertical, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_yaw = wrapf(_yaw, -PI, PI)
	_apply_rotation()


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	if spring_arm != null:
		spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)
