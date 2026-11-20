class_name DifficultySelect
extends CanvasLayer
## Tela mínima de escolha de dificuldade ao criar um mundo novo (proposta P-SV-10).
##
## Pausa o jogo enquanto aberta e mostra o cursor. Não é um menu principal:
## só aparece quando não há save do mundo.

@export var manager: DifficultyManager

@onready var _panel: Control = %Panel
@onready var _buttons: VBoxContainer = %Buttons
@onready var _description: Label = %Description


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	if manager != null:
		manager.selection_requested.connect(open)
		for preset in manager.presets:
			var button := Button.new()
			button.text = preset.display_name
			button.custom_minimum_size = Vector2(320, 48)
			button.pressed.connect(_choose.bind(preset.id))
			button.mouse_entered.connect(func(): _description.text = preset.description)
			button.focus_entered.connect(func(): _description.text = preset.description)
			_buttons.add_child(button)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var preset := manager.get_preset(manager.default_preset_id)
	_description.text = preset.description if preset != null else ""
	if _buttons.get_child_count() > 1:
		(_buttons.get_child(1) as Button).grab_focus()


func _choose(id: StringName) -> void:
	if manager.choose(id):
		_panel.visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
